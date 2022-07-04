import pycurl
import json
from io import BytesIO

def get_data(url='https://google.com', 
                   method='GET', 
                   headers={}):
    ''' 
    @TODO
    Support also header values optional
    Set method GET/POST
    Validate all options
    '''
    #default GET : if POSt build payload
    buffer = BytesIO()
    c = pycurl.Curl()
    c.setopt(pycurl.OPT_CERTINFO, 1)
    c.setopt(c.URL, url)
    c.setopt(c.WRITEDATA, buffer)
    c.perform()
    response =  {
        "STATUS": c.getinfo(pycurl.HTTP_CODE),
        "NAMELOOKUP_TIME":  c.getinfo(pycurl.NAMELOOKUP_TIME),
        "APPCONNECT_TIME)":  c.getinfo(pycurl.APPCONNECT_TIME),
        "CONNECT_TIME":  c.getinfo(pycurl.CONNECT_TIME),
        "TOTAL_TIME":  c.getinfo(pycurl.TOTAL_TIME),
        "SPEED_DOWNLOAD":  c.getinfo(pycurl.SPEED_DOWNLOAD),
#        "CERTIFICATE":  c.getinfo(pycurl.INFO_CERTINFO)
    }
    c.close()
    return response

# Opening JSON file
f = open('config/AFAS API.postman_collection.json')
data = json.load(f)

# Iterate over them
for item in data['item']:
    name = item["name"]
    method = item["request"]["method"]
    #headers=item["request"]["headers"]
    #payload=item["payload"]
    if 'url' in item['request']:
        if 'raw' in item['request']['url']:
            url=item["request"]["url"]["raw"]
            print(get_data(url=url, method=method))
    else:
        print("Skipped ", name)
