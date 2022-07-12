#!/usr/bin/env python3
"""Test URL endpoints defined within Postman Collections and report to Azure AppInsights.

Copyright 2022 Eurofiber | Cloud Infra

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

__version__ = "0.1.0"
__author__ = "Alexander Kuemmel <akisys@github>"
__license__ = "Apache License 2.0"


import sys
assert sys.version_info >= (3, 7)

import hashlib
import dataclasses
import typer
import requests
import json
import subprocess
import shutil
import tempfile
import logging
import ssl
import re
import socket
import ipaddress
import crl_checker

from enum import IntEnum
from typing import Any, Tuple, List
from pathlib import Path
from datetime import datetime
from pprint import pprint as pp

from cryptography import x509
from applicationinsights import TelemetryClient
from urlpath import URL

app = typer.Typer()
testcmd = "newman"
testcmd_opts = "run --insecure --reporters json"

# logging setup
format = "%(asctime)s - %(levelname)s - %(message)s"
logging.basicConfig(format=format, level=logging.DEBUG, datefmt="%H:%M:%S")


class RC(IntEnum):
    BASIC = 1
    HTTP = 2
    REQUEST = 3
    TIMER = 4
    OTHER = 127


@dataclasses.dataclass
class pm_request_url:
    host: list = dataclasses.field(default_factory=list)
    protocol: str = None
    port: str = None
    raw: str = dataclasses.field(default_factory=str)
    query: list = dataclasses.field(default_factory=list)
    path: list = dataclasses.field(default_factory=list)
    variable: list = dataclasses.field(default_factory=list)
    url_parsed: URL = None
    url_hashed: str = None
    hostinfo_hashed: str = None

    def __post_init__(self):
        # try parsing url data
        if len(self.raw) > 0:
            self.url_parsed = URL(self.raw)
        elif len(self.host) > 0:
            url_path = "/".join(self.path)
            url_query = "&".join(
                [
                    "{0}={1}".format(item.get("key"), item.get("value"))
                    for item in self.query
                ]
            )
            reconstructed_url = "{schema}://{hostname}{port}{path}{query}".format(
                schema=self.protocol,
                hostname=".".join(self.host),
                port=f":{self.port}" if self.port else "",
                path=f"/{url_path}" if len(url_path) > 0 else "/",
                query=f"?{url_query}" if len(url_query) > 0 else "",
            )
            self.url_parsed = URL(reconstructed_url)

        if self.url_parsed:

            # try populating fields from parsed url if missing
            if not self.protocol:
                self.protocol = self.url_parsed.scheme
            if not self.port:
                self.port = self.url_parsed.port
            if not self.port and self.protocol.lower() == "https":
                self.port = "443"

            # adjust parsed url with new components
            self.url_parsed = self.url_parsed.with_components(port=self.port)

            # get a unique enough hash from parsed url
            self.url_hashed = hashlib.sha1(
                self.url_parsed.as_uri().encode("utf-8")
            ).hexdigest()
            self.hostinfo_hashed = hashlib.sha1(
                str(self.url_parsed.hostinfo).encode("utf-8")
            ).hexdigest()


@dataclasses.dataclass
class pm_request:
    method: str
    url: pm_request_url
    body: dict = dataclasses.field(default_factory=dict)
    header: list = dataclasses.field(default_factory=list)
    auth: dict = dataclasses.field(default_factory=dict)

    def __post_init__(self):
        self.url = pm_request_url(**self.url)


@dataclasses.dataclass
class pm_response:
    id: str
    status: str
    code: int
    responseTime: int
    responseSize: int
    header: list = dataclasses.field(default_factory=list)
    stream: dict = dataclasses.field(default_factory=dict)
    cookie: list = dataclasses.field(default_factory=list)

    def get_headers(self) -> dict:
        return dict([(hdr.get("key"), hdr.get("value")) for hdr in self.header])


@dataclasses.dataclass
class pm_item:
    id: str
    name: str
    request: pm_request
    event: Any
    response: Any

    def __post_init__(self):
        self.request = pm_request(**self.request)


@dataclasses.dataclass
class pm_execution_result:
    id: str
    item: pm_item
    cursor: dict
    request: Any = None
    response: Any = None
    requestError: dict = dataclasses.field(default_factory=dict)
    assertions: list = dataclasses.field(default_factory=list)

    def __post_init__(self):
        self.item = pm_item(**self.item)
        if self.request:
            self.request = pm_request(**self.request)
        if self.response:
            self.response = pm_response(**self.response)
        if self.assertions:
            self.assertions = [
                pm_assertion(**assertion_item) for assertion_item in self.assertions
            ]


@dataclasses.dataclass
class pm_assertion_test_error:
    name: str
    index: int
    test: str
    message: str
    stack: str


@dataclasses.dataclass
class pm_assertion:
    assertion: str
    skipped: bool
    error: Any = None

    def __post_init__(self):
        if self.error:
            self.error = pm_assertion_test_error(**self.error)


@dataclasses.dataclass
class pm_failure_result:
    source: pm_item
    error: dict
    at: str
    parent: dict
    cursor: dict

    def __post_init__(self):
        self.source = pm_item(**self.source)

    def __str__(self):
        return "ts: {0} | request_name: {1} | failure_type: {2} | failure_at: {3} | failure_msg: {4}".format(
            self.error.get("timestamp"),
            self.source.name,
            self.error.get("name"),
            self.at,
            self.error.get("message"),
        )


@dataclasses.dataclass
class sslcert_result_document:
    url: pm_request_url = None
    host_cert: x509.Certificate = None
    is_self_signed: bool = False
    is_revoked: bool = False
    crl_verification_failures: list = dataclasses.field(default_factory=list)
    revoked_msg: Any = None
    today_until_expired_days: int = 0
    valid_until_today_days: int = 0
    error_type: str = None
    error_code: int = 0
    error_msg_raw: str = None

    def __post_init__(self):
        if not self.error_type and self.error_code == 0:
            dt_today = datetime.today()
            self.today_until_expired_days = (
                self.host_cert.not_valid_after - dt_today
            ).days
            self.valid_until_today_days = (
                dt_today - self.host_cert.not_valid_before
            ).days
            self.is_self_signed = is_self_signed_cert(self.host_cert)
            if not self.is_self_signed:
                try:
                    crl_checker.check_revoked_crypto_cert(self.host_cert)
                except crl_checker.Revoked as revoked:
                    self.is_revoked = True
                    self.revoked_msg = revoked
                except crl_checker.Error as other:
                    self.crl_verification_failures.append(other)
                else:
                    self.is_revoked = False


@dataclasses.dataclass
class check_result_document(pm_item):
    assertions: list = dataclasses.field(default_factory=list)
    failure: pm_failure_result = None
    ssl: sslcert_result_document = None
    test_ssl_success: bool = False
    test_success: bool = False
    test_messages: list = dataclasses.field(default_factory=list)

    def get_result_properties(self) -> dict:
        output = dict(
            item_id=self.id,
            item_name=self.name,
        )
        if self.response:
            rsp_output = dict(
                rsp_status=self.response.status,
                rsp_code=self.response.code,
                rsp_headers=self.response.get_headers(),
                rsp_time=self.response.responseTime,
                rsp_size=self.response.responseSize,
            )
            output.update(rsp_output)
        if self.ssl and self.ssl.host_cert:
            # extend output with ssl info
            ssl_output = dict(
                ssl_issuer=str(self.ssl.host_cert.issuer),
                ssl_subject=str(self.ssl.host_cert.subject),
                ssl_valid_date=self.ssl.host_cert.not_valid_before.isoformat(),
                ssl_expired_date=self.ssl.host_cert.not_valid_after.isoformat(),
            )
            output.update(ssl_output)
        # output mods for appinsights
        for k in output:
            if isinstance(output.get(k), dict) or isinstance(output.get(k), list):
                output[k] = json.dumps(output.get(k))
        return output

    def validate_certificate(
        self,
        self_signed_invalid: bool = True,
        check_expiration: bool = True,
        expiration_gracetime_days: int = 14,
    ) -> bool:
        logging.debug("Validating certificate test data.")
        ssl_test_failed = False
        if not self.ssl:
            logging.debug("No SSL data found.")
            self.test_messages.append("No SSL data found where one was expected.")
            ssl_test_failed |= True
        elif self.ssl.error_type or self.ssl.error_code and not self.ssl.host_cert:
            logging.debug("Check SSL routine underlay errors.")
            error_msg = f"Internal error during SSL cert retrieval. Type: [{self.ssl.error_type}] | Code: [{self.ssl.error_code}] | Raw: [{self.ssl.error_msg_raw}]"
            self.test_messages.append(error_msg)
            ssl_test_failed |= True
        elif self.ssl.is_self_signed and self_signed_invalid:
            logging.debug("Check SSL cert self-signed and therefor invalid.")
            self.test_messages.append(
                "Self-Signed certificate detected where valid certification is required."
            )
            ssl_test_failed |= True
        elif self.ssl.is_revoked:
            logging.debug("Check SSL cert revoked.")
            self.test_messages.append("Revoked certificate detected.")
            ssl_test_failed |= True
        elif check_expiration and self.ssl.today_until_expired_days < 0:
            logging.debug("Check SSL cert already expired.")
            self.test_messages.append(
                f"Certificate expired [{self.ssl.host_cert.not_valid_after.isoformat()}]"
            )
            ssl_test_failed |= True
        elif (
            check_expiration
            and self.ssl.today_until_expired_days < expiration_gracetime_days
        ):
            logging.debug(
                f"Check SSL cert expiry shorter than grace time [{expiration_gracetime_days}] days."
            )
            self.test_messages.append(
                f"Certificate expiry [{self.ssl.host_cert.not_valid_after.isoformat()}] within {expiration_gracetime_days} days"
            )
            ssl_test_failed |= True

        logging.debug("All SSL cert related checks finished.")
        self.test_ssl_success = not ssl_test_failed
        return self.test_ssl_success

    def validate_test_report(self, acceptable_response_codes: list[int] = [200], include_ssl_test_results: bool = True) -> bool:
        logging.debug("Validating test report data.")
        if self.failure:
            logging.debug("Found failures, test failed.")
            self.test_success = False
            self.test_messages.append(str(self.failure))
        else:
            logging.debug("No failures.")
            self.test_success = True

        if self.response:
            logging.debug(f"Evaluating acceptable response code {self.response.code}")
            self.test_success &= (self.response.code in acceptable_response_codes)

        if include_ssl_test_results:
            logging.debug("Evaluating SSL/TLS test result")
            self.test_success &= self.test_ssl_success

        if self.test_success:
            logging.info("Test passed")
            self.test_messages.append("Passed")
        else:
            logging.info("Test failed")
        return self.test_success


def load_pm_collection_url(url: str, timeout: Any = 5) -> dict:
    data = {}
    rc, msg = 0, None
    try:
        rsp = requests.get(url, allow_redirects=True, verify=True, timeout=timeout)
        rsp.raise_for_status()
        data = rsp.json()
    except requests.URLRequired as e:
        msg = e
        rc = RC.BASIC
    except requests.Timeout as e:
        msg = e
        rc = RC.TIMER
    except requests.HTTPError as e:
        msg = e
        rc = RC.HTTP
    except requests.RequestException as ex:
        msg = ex
        rc = RC.REQUEST
    except Exception as ex:
        msg = ex
        rc = RC.OTHER
    else:
        return data
    typer.echo(msg)
    raise typer.Exit(rc)


def load_pm_collection(ref: str) -> dict:
    ref_data = {}
    path_ref = Path(ref)
    if path_ref.is_file():
        with path_ref.open(mode="r") as fp:
            ref_data = json.load(fp)
    else:
        ref_data = load_pm_collection_url(url=ref)
    return ref_data


def run_pm_collection_test(
    data: dict,
    nm_timeout_collection: int = None,
    nm_timeout_request: int = None,
    nm_timeout_script: int = None,
    py_subproc_timeout: int = None,
) -> Tuple:
    if not shutil.which(testcmd):
        raise Exception(f"Could not find executable ({testcmd}) in $PATH")
    report_data = None
    error_rc = 0
    error_raw = None
    # customize sub-command options
    timeout_overrides = ""
    if nm_timeout_collection:
        timeout_overrides = f"{timeout_overrides} --timeout {nm_timeout_collection}"
        py_subproc_timeout = round((nm_timeout_collection / 1000) + 60)
    if nm_timeout_request:
        timeout_overrides = (
            f"{timeout_overrides} --timeout-request {nm_timeout_request}"
        )
    if nm_timeout_script:
        timeout_overrides = f"{timeout_overrides} --timeout-script {nm_timeout_script}"
    timeout_overrides = timeout_overrides.strip()

    with tempfile.TemporaryDirectory() as tempdir:
        data_input_file = Path(f"{tempdir}/input_collection.json")
        data_output_file = Path(f"{tempdir}/output_report.json")
        with data_input_file.open(mode="w") as collection_fp:
            json.dump(data, collection_fp)
        cmd_base = f"{testcmd} {testcmd_opts} --reporter-json-export {data_output_file.absolute()} {timeout_overrides} {data_input_file.absolute()}".split()
        proc = subprocess.run(
            cmd_base,
            shell=False,
            stderr=subprocess.PIPE,
            stdout=subprocess.PIPE,
            encoding="utf-8",
            check=False,
            timeout=py_subproc_timeout,
        )
        if proc.returncode > 0:
            logging.debug("handle test command error codes")
            error_rc = proc.returncode
            error_raw = "{0}\n{1}".format(proc.stderr, proc.stdout)
            if not data_output_file.is_file():
                logging.critical(f"RC:{error_rc} | RAW:{error_raw}")
                raise RuntimeError("Test command failed without output report!")
        if data_output_file.is_file():
            with data_output_file.open(mode="r") as report_fp:
                report_data = json.load(report_fp)
    return (report_data, error_rc, error_raw)


def patch_report_collection_item_data(
    collection_data: dict, parent_level_name: str = None
):
    data_store = []
    if "item" not in collection_data:
        # we found a leave
        current_leave_item_name = collection_data.get("name")
        new_leave_item_name = f"{parent_level_name} / {current_leave_item_name}"
        collection_data.update(dict(name=new_leave_item_name))
        return collection_data

    if collection_data.get("name"):
        # we are in a subfolder structure of the collection data
        current_level_name = "[{0}]".format(collection_data.get("name", "/"))
    else:
        # this is likely root level of the collection
        current_level_name = ""
    if parent_level_name:
        current_level_name = f"{parent_level_name} / {current_level_name}"
    for coll_item in collection_data.get("item"):
        patched = patch_report_collection_item_data(
            collection_data=coll_item, parent_level_name=current_level_name
        )
        if isinstance(patched, dict):
            data_store.append(patched)
        elif isinstance(patched, list):
            data_store.extend(patched)
    return data_store


def update_check_item_doc(
    check_item_doc: check_result_document,
    pm_exec_doc: pm_execution_result = None,
    pm_fail_doc: pm_failure_result = None,
    sslcert_doc: sslcert_result_document = None,
):
    if check_item_doc is None:
        raise RuntimeError("Item doc should not me null.")
    if pm_exec_doc:
        check_item_doc.response = pm_exec_doc.response
        check_item_doc.assertions = pm_exec_doc.assertions
    if pm_fail_doc:
        check_item_doc.failure = pm_fail_doc
    if sslcert_doc:
        check_item_doc.ssl = sslcert_doc


def process_pm_collection_report(data: dict, report_error_rc: int):
    datastore = {}
    if "run" not in data:
        raise ValueError("PM Report object does not contain 'run' information.")
    elif "collection" not in data:
        raise ValueError("PM Report object does not contain 'collection' information.")
    # extract collection item data
    for coll_item in patch_report_collection_item_data(data.get("collection", {})):
        check_item_doc = check_result_document(**coll_item)
        datastore[check_item_doc.id] = check_item_doc
    # handle failure output mixin
    if report_error_rc > 0:
        # TODO: determine special handling of report failures
        logging.debug("extracting failures")
        for fail in data.get("run", {}).get("failures", []):
            fail_doc = pm_failure_result(**fail)
            logging.warning(fail_doc)
            if fail_doc.source.id in datastore:
                update_check_item_doc(
                    check_item_doc=datastore.get(fail_doc.source.id),
                    pm_fail_doc=fail_doc,
                )
    # extract execution data
    for exec_item in data.get("run", {}).get("executions", []):
        pm_exec_result_doc = pm_execution_result(**exec_item)
        if pm_exec_result_doc.id not in datastore:
            logging.critical(
                "This should not happen, no ITEM ID found in datastore for execution item."
            )
            raise typer.Exit(RC.BASIC)
        else:
            # merge in fields extracted from data
            update_check_item_doc(
                check_item_doc=datastore.get(pm_exec_result_doc.id),
                pm_exec_doc=pm_exec_result_doc,
            )
    return datastore


def pm_collection_extract_urls(data: dict) -> list:
    collection = list()
    if "item" in data:
        for item in data.get("item", []):
            collection.extend(pm_collection_extract_urls(item))
    elif "request" in data:
        request_url = data.get("request").get("url")
        if not request_url:
            return collection
        if isinstance(request_url, dict):
            url_doc = pm_request_url(**data.get("request").get("url"))
        elif isinstance(request_url, str):
            url_doc = pm_request_url(**dict(raw=request_url))
        collection.append(url_doc)
    return collection


def is_self_signed_cert(cert: x509.Certificate) -> bool:
    """Using heuristic check for self-signed certificates.
    Details described in: https://www.rfc-editor.org/rfc/rfc3280#section-4.2.1.1
    Implementation hint reference:
    https://security.stackexchange.com/questions/93162/how-to-know-if-certificate-is-self-signed
    """
    auth_key_id = None
    subj_key_id = None
    for ext in cert.extensions:
        if isinstance(ext.value, x509.AuthorityKeyIdentifier):
            auth_key_id = ext.value.key_identifier
        if isinstance(ext.value, x509.SubjectKeyIdentifier):
            subj_key_id = ext.value.key_identifier
    if auth_key_id and subj_key_id:
        return auth_key_id == subj_key_id
    elif not auth_key_id:
        # valid CAs need to provide AuthenticationKeyIdentifier, so this is self-signed
        return True
    else:
        # anything else we don't cover yet
        logging.warning("SSL check heuristic dead end. Check Implementation!")
        raise typer.Exit(RC.OTHER)


def retrieve_server_certificates(urls: list, ssl_timeout: float = 5.0) -> dict:
    results = {}
    for url in urls:
        if url.hostinfo_hashed in results:
            continue
        # retrieve host cert without verification
        address = (url.url_parsed.hostname, url.url_parsed.port)
        try:
            host_pem = ssl.get_server_certificate(address, timeout=ssl_timeout)
            host_cert = x509.load_pem_x509_certificate(host_pem.encode("utf-8"))
            results[url.hostinfo_hashed] = sslcert_result_document(
                url=url,
                host_cert=host_cert,
            )
        except OSError as ex:
            results[url.hostinfo_hashed] = sslcert_result_document(
                error_code=int(ex.errno) if ex.errno else RC.BASIC,
                error_type=str(type(ex).__name__),
                error_msg_raw=ex.strerror,
            )
        except Exception as ex:
            results[url.hostinfo_hashed] = sslcert_result_document(
                error_code=RC.OTHER,
                error_type=str(type(ex).__name__),
                error_msg_raw=str(ex),
            )
    return results


def estimate_location(auto_location_test_hostinfo: str) -> str:
    """Returns an IP-Address used to communicate to external endpoints."""

    logging.info(
        f"Determining location from test connection to [{auto_location_test_hostinfo}]"
    )
    host_info_parts = auto_location_test_hostinfo.split(":")
    host, port, *_ = tuple(host_info_parts)
    proto = "TCP"
    if len(host_info_parts) > 2:
        proto = host_info_parts[2].upper()
    port = int(port)
    ip = ipaddress.ip_address(host)

    if isinstance(ip, ipaddress.IPv4Address):
        sock_fam = socket.AF_INET
    elif isinstance(ip, ipaddress.IPv6Address):
        sock_fam = socket.AF_INET6
    else:
        raise ValueError("Require valid IP address in test hostinfo.")

    if proto in ["UDP", "TCP"]:
        sock_proto = socket.IPPROTO_UDP if proto == "UDP" else socket.IPPROTO_TCP
        sock_type = socket.SOCK_DGRAM if proto == "UDP" else socket.SOCK_STREAM
    else:
        raise ValueError("Required protocol not found in test hostinfo.")

    s = socket.socket(sock_fam, sock_type, sock_proto)
    s.connect((str(ip), port))
    socket_source_ip = ipaddress.ip_address(s.getsockname()[0])
    return str(socket_source_ip)


def sanitize_appinsights(payload: dict) -> dict:
    """
    Mitigate AppInsights submission restrictions:
    name: 1-64, 0-1A-Za-z, hyphen, space, needs to start with char
    """
    name = str(payload.get("name"))
    name = name.replace("/", "--")
    name = re.sub(r"(?:[^a-zA-Z\d\ \-])", " ", name)
    name = re.sub(r"(\ )+", r"\1", name)
    name = re.sub(r"(\-\-)+", r"\1", name)
    name = name.strip()
    if re.match(r"^[^a-zA-Z]", name):
        name = f"C-{name}"
    if len(name) > 64:
        name = f"{name[:-3]}..."
    payload.update(dict(name=name))
    return payload


def publish_in_appinsights(data: dict, tc: TelemetryClient, location: str = None):
    for report_doc in data.values():
        logging.debug(f"Preparing payload for document id: [{report_doc.id}]")
        tc.context.operation.id = report_doc.id
        payload = dict(
            name=report_doc.name,
            duration=report_doc.response.responseTime if report_doc.response else 0,
            success=report_doc.test_success,
            run_location=location,
            message=" ".join(report_doc.test_messages),
            properties=report_doc.get_result_properties(),
        )
        payload = sanitize_appinsights(payload)
        logging.debug(f"Payload of document id [{report_doc.id}] follows:")
        logging.debug(str(payload))
        # send results
        tc.track_availability(**payload)
        tc.flush()
        logging.info(f"Report for document id [{report_doc.id}] submitted.")
    pass


@app.command()
def urlcheck(
    ai_instrumentation_key: str = typer.Option(..., envvar="AI_INSTRUMENTATION_KEY"),
    pm_collection_url: str = typer.Option(..., envvar="PM_COLLECTION_URL"),
    nm_timeout_collection: int = typer.Option(
        default=300000, envvar="NM_TIMEOUT_COLLECTION"
    ),
    nm_timeout_request: int = typer.Option(default=5000, envvar="NM_TIMEOUT_REQUEST"),
    nm_timeout_script: int = typer.Option(default=5000, envvar="NM_TIMEOUT_SCRIPT"),
    certificate_validation_check: bool = typer.Option(
        default=True, envvar="CERTIFICATE_VALIDATION_CHECK"
    ),
    certificate_ignore_self_signed: bool = typer.Option(
        default=False, envvar="CERTIFICATE_IGNORE_SELF_SIGNED"
    ),
    certificate_check_expiration: bool = typer.Option(
        default=True, envvar="CERTIFICATE_CHECK_EXPIRATION"
    ),
    certificate_expiration_gracetime_days: int = typer.Option(
        default=14, envvar="CERTIFICATE_EXPIRATION_GRACETIME_DAYS"
    ),
    location: str = typer.Option(default=None, envvar="LOCATION"),
    auto_location_test_hostinfo: str = typer.Option(
        default="1.1.1.1:53:UDP", envvar="AUTO_LOCATION_TEST_HOSTINFO"
    ),
    verbosity: int = typer.Option(None, "-v", count=True),
    rc_range: Tuple[int, int] = typer.Option((None, None), help="Start (inclusive) End (exclusive) range of acceptable response codes for successful tests."),
    rc_list: List[int] = typer.Option([200], "-r", help="Acceptable response code. Multiple uses."),
):
    call_args = locals()

    logger = logging.getLogger()
    if not verbosity:
        logger.setLevel(logging.ERROR)
    elif verbosity == 1:
        logger.setLevel(logging.WARNING)
    elif verbosity == 2:
        logger.setLevel(logging.INFO)
    elif verbosity >= 3:
        logger.setLevel(logging.DEBUG)

    logging.info(f"Starting test run for collection url: [{pm_collection_url}]")
    logging.debug(f"Startup state: {call_args}")

    data = load_pm_collection(pm_collection_url)
    pm_test_results, error_rc, _ = run_pm_collection_test(
        data,
        nm_timeout_collection=nm_timeout_collection,
        nm_timeout_request=nm_timeout_request,
        nm_timeout_script=nm_timeout_script,
    )
    pm_report_data = process_pm_collection_report(pm_test_results, error_rc)

    if certificate_validation_check:
        pm_url_list = pm_collection_extract_urls(data)
        sslcert_report_data = retrieve_server_certificates(pm_url_list)
        # consolidate report data
        for report_item in pm_report_data.values():
            if report_item.request.url.hostinfo_hashed in sslcert_report_data:
                update_check_item_doc(
                    check_item_doc=report_item,
                    sslcert_doc=sslcert_report_data.get(
                        report_item.request.url.hostinfo_hashed
                    ),
                )

    # evaluate report data
    for test_report_doc in pm_report_data.values():
        if certificate_validation_check:
            test_report_doc.validate_certificate(
                self_signed_invalid=not certificate_ignore_self_signed,
                check_expiration=certificate_check_expiration,
                expiration_gracetime_days=certificate_expiration_gracetime_days,
            )

        rc_accept_list = []
        (rc_range_start, rc_range_end) = rc_range
        if rc_range_start and rc_range_end:
            rc_accept_list = list(range(rc_range_start, rc_range_end))
        if rc_list:
            rc_accept_list.extend(rc_list)
        rc_accept_list = list(set(rc_accept_list))

        test_report_doc.validate_test_report(
            acceptable_response_codes=rc_accept_list,
            include_ssl_test_results=certificate_validation_check,
        )

    if not location:
        location = estimate_location(auto_location_test_hostinfo)

    # publish report data
    appinsights_client = TelemetryClient(ai_instrumentation_key)
    publish_in_appinsights(
        data=pm_report_data, tc=appinsights_client, location=location
    )
    logging.info(f"Reached end of run for collection url: [{pm_collection_url}]")


if __name__ == "__main__":
    app()
