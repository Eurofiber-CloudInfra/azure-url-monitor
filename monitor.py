import pycurl
from io import BytesIO

#default GET
buffer = BytesIO()
c = pycurl.Curl()
c.setopt(pycurl.OPT_CERTINFO, 1)
c.setopt(c.URL, 'https://google.com')
c.setopt(c.WRITEDATA, buffer)
c.perform()

# ---- See https://curl.se/libcurl/c/curl_easy_getinfo.html
print( "Name lookup time : ", c.getinfo(pycurl.NAMELOOKUP_TIME) )
# Time from start until remote host or proxy completed.
print( "Connect time : ", c.getinfo(pycurl.CONNECT_TIME) )
# Time from start until SSL/SSH handshake completed.
print( "App Connect time: ", c.getinfo(pycurl.APPCONNECT_TIME) )
# Average download speed
print( "Download speed: ", c.getinfo(pycurl.SPEED_DOWNLOAD ))
print( "Totaltime : ",c.getinfo(pycurl.TOTAL_TIME) )
print('-----------------')
#print("Certificate dump : %s",c.getinfo(pycurl.INFO_CERTINFO))
c.close()
