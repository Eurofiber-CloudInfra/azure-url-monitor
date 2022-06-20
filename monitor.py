#!/usr/bin/env python3

from enum import IntEnum
import hashlib
from typing import Any, Tuple
from pathlib import Path
import dataclasses
import typer
import requests
import json
import subprocess
import shutil
import tempfile
import logging
import ssl
from datetime import datetime
from cryptography import x509
import crl_checker

from applicationinsights import TelemetryClient

from urlpath import URL
from pprint import pprint as pp

app = typer.Typer()
testcmd = "newman"
testcmd_opts = "run --reporters json"

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
    protocol: str = "unknown"
    port: str = None
    raw: str = dataclasses.field(default_factory=str)
    query: list = dataclasses.field(default_factory=list)
    path: list = dataclasses.field(default_factory=list)
    variable: list = dataclasses.field(default_factory=list)
    url_parsed: URL = None
    url_hashed: str = None
    hostinfo_hashed: str = None

    def __post_init__(self):
        if not self.port and self.protocol.lower() == "https":
            self.port = "443"
        if len(self.raw) > 0:
            self.url_parsed = URL(self.raw).with_components(port=self.port)
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
    url: pm_request_url
    host_cert: x509.Certificate
    is_self_signed: bool = False
    is_revoked: bool = False
    crl_verification_failures: list = dataclasses.field(default_factory=list)
    revoked_msg: Any = None
    today_until_expired_days: int = 0
    valid_until_today_days: int = 0

    def __post_init__(self):
        dt_today = datetime.today()
        self.is_self_signed = is_self_signed_cert(self.host_cert)
        self.today_until_expired_days = (self.host_cert.not_valid_after - dt_today).days
        self.valid_until_today_days = (dt_today - self.host_cert.not_valid_before).days
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
    test_failed: bool = False
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
        if self.ssl:
            # extend output with ssl info
            ssl_output = dict(
                ssl_issuer=str(self.ssl.host_cert.issuer),
                ssl_subject=str(self.ssl.host_cert.subject),
                ssl_valid_date=self.ssl.host_cert.not_valid_before.isoformat(),
                ssl_expired_date=self.ssl.host_cert.not_valid_after.isoformat(),
            )
            output.update(ssl_output)
        # if no failed test
        if not self.test_failed:
            self.test_messages.append("Passed")
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
        if not self.ssl:
            self.test_failed = self.test_failed or True
            self.test_messages.append("No SSL data found where one was expected.")
        elif self.ssl.is_self_signed and self_signed_invalid:
            self.test_failed = self.test_failed or True
            self.test_messages.append(
                "Self-Signed certificate detected where valid certification is required."
            )
        elif self.ssl.is_revoked:
            self.test_failed = self.test_failed or True
            self.test_messages.append("Revoked certificate detected.")
        elif self.ssl.today_until_expired_days < 0:
            self.test_failed = self.test_failed or True
            self.test_messages.append(
                f"Certificate expired [{self.ssl.host_cert.not_valid_after.isoformat()}]"
            )
        elif (
            check_expiration
            and self.ssl.today_until_expired_days < expiration_gracetime_days
        ):
            self.test_failed = self.test_failed or True
            self.test_messages.append(
                f"Certificate expiry [{self.ssl.host_cert.not_valid_after.isoformat()}] within {expiration_gracetime_days} days"
            )
        return self.test_failed

    def validate_test_report(self) -> bool:
        if self.failure:
            self.test_failed = self.test_failed or True
            self.test_messages.append(str(self.failure))
        return self.test_failed


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


def run_pm_collection_test(data: dict) -> Tuple:
    if not shutil.which(testcmd):
        raise Exception(f"Could not find executable ({testcmd}) in $PATH")
    report_data = {}
    error_rc = 0
    error_raw = None
    with tempfile.TemporaryDirectory() as tempdir:
        data_input_file = Path(f"{tempdir}/input_collection.json")
        data_output_file = Path(f"{tempdir}/output_report.json")
        with data_input_file.open(mode="w") as collection_fp:
            json.dump(data, collection_fp)
        cmd_base = f"{testcmd} {testcmd_opts} --reporter-json-export {data_output_file.absolute()} {data_input_file.absolute()}".split()
        proc = subprocess.run(
            cmd_base,
            shell=False,
            stderr=subprocess.PIPE,
            stdout=subprocess.PIPE,
            encoding="utf-8",
            check=False,
        )
        if proc.returncode > 0:
            logging.debug("handle test command error codes")
            error_rc = proc.returncode
            error_raw = "{0}\n{1}".format(proc.stderr, proc.stdout)
            if not data_output_file.is_file:
                logging.critical(f"RC:{error_rc} | RAW:{error_raw}")
                raise ValueError("Test command failed without output report!")
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
        current_level_name = "root"
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

    for item in data.get("item", []):
        if "item" in item:
            collection.extend(pm_collection_extract_urls(item))
    else:
        url_doc = pm_request_url(**item.get("request").get("url"))
        collection.append(url_doc)

    return collection


def is_self_signed_cert(cert: x509.Certificate) -> bool:
    """
    Using heuristic check for self-signed certificates described in:
    https://www.rfc-editor.org/rfc/rfc3280#section-4.2.1.1
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


def retrieve_server_certificates(urls: list) -> dict:
    results = {}
    for url in urls:
        if url.hostinfo_hashed in results:
            continue
        # retrieve host cert without verification
        address = (url.url_parsed.hostname, url.url_parsed.port)
        host_pem = ssl.get_server_certificate(address)
        host_cert = x509.load_pem_x509_certificate(host_pem.encode("utf-8"))
        results[url.hostinfo_hashed] = sslcert_result_document(
            url=url,
            host_cert=host_cert,
        )
    return results


def publish_in_appinsights(data: dict, tc: TelemetryClient, location: str = None):
    for report_doc in data.values():
        tc.context.operation.id = report_doc.id
        name = report_doc.name
        location = location
        duration_ms = report_doc.response.responseTime if report_doc.response else 0
        success = not report_doc.test_failed
        message = " ".join(report_doc.test_messages)
        custom_properties = report_doc.get_result_properties()
        # send results
        tc.track_availability(
            name,
            duration_ms,
            success,
            location,
            message=message,
            properties=custom_properties,
        )
        tc.flush()
    pass


@app.command()
def urlcheck(
    ai_instrumentation_key: str = typer.Option(..., envvar="AI_INSTRUMENTATION_KEY"),
    pm_collection_url: str = typer.Option(..., envvar="PM_COLLECTION_URL"),
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
):
    data = load_pm_collection(pm_collection_url)
    pm_test_results, error_rc, _ = run_pm_collection_test(data)
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
        test_report_doc.validate_test_report()
        pass

    # publish report data
    appinsights_client = TelemetryClient(ai_instrumentation_key)
    publish_in_appinsights(
        data=pm_report_data, tc=appinsights_client, location=location
    )
    pass


if __name__ == "__main__":
    app()
