// We want to send:
//❯ curl -v http://1.2.3.4/jsonrpc -d '{"jsonrpc":"2.0","method":"session.login_with_password","params":["root","pass","1.0","gtntest"],"id":1}'
//*   Trying 1.2.3.4:80...
//* Connected to 1.2.3.4 (1.2.3.4) port 80
//* using HTTP/1.x
//> POST /jsonrpc HTTP/1.1
//> Host: 1.2.3.4
//> User-Agent: curl/8.15.0
//> Accept: */*
//> Content-Length: 104
//> Content-Type: application/x-www-form-urlencoded
//>
//* upload completely sent off: 104 bytes
//< HTTP/1.1 200 OK
//< content-length: 126
//< connection: keep-alive
//< cache-control: no-cache, no-store
//< content-type: application/json
//< Access-Control-Allow-Origin: *
//< Access-Control-Allow-Headers: X-Requested-With
//<
//* Connection #0 to host 1.2.3.4 left intact
//{"jsonrpc":"2.0","error":{"code":1,"message":"SESSION_AUTHENTICATION_FAILED","data":["root","Authentication failure"]},"id":1}
