local http = require "http"
local shortport = require "shortport"
local stdnse = require "stdnse"
local string = require "string"

description = [[
Script by @psc4re for checking against CVE-2021-21972, CVE-2021-21973 Vulnerability in vCenter. The script also additionally prints the vSphere Version and Build Number
]]

---
-- @usage
-- nmap --script vcenter_rcecheck.nse -p443 <host> (optional: --script-args output=report.txt)
--
-- @output
-- | vcrce-check:
-- |   Server version: VMware vCenter Server 7.0.1 build:17005016
-- |   CVE-2021-21972: Vulnerable!
----------------------------------------------------------

author = "psc4re"
license = "Same as Nmap--See https://nmap.org/book/man-legal.html"
categories = {"default", "discovery", "safe"}
portrule = shortport.http


local function get_file(host, port, path)
  local req
  req='<soap:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Header><operationID>00000001-00000001</operationID></soap:Header><soap:Body><RetrieveServiceContent xmlns="urn:internalvim25"><_this xsi:type="ManagedObjectReference" type="ServiceInstance">ServiceInstance</_this></RetrieveServiceContent></soap:Body></soap:Envelope>'

  local result = http.post( host, port, path, nil, nil, req)
  if(result['status'] ~= 200 or result['content-length'] == 0) then
    return false, "Couldn't download file: " .. path
  end

  return true, result.body
end


local function getVulnStatus(host, port)
  local CVE202121972, CVE202121973
  resp = http.get( host, port,"/ui/vropspluginui/rest/services/uploadova" )
  if(resp['status'] == 405) then
    CVE202121972 = true
  end
  return  CVE202121972 
end


action = function(host, port)
  local res = getVulnStatus(host, port)
  local result, body = get_file(host, port, "/sdk")
  local outputFile = stdnse.get_script_args(SCRIPT_NAME..".output") or nil
  local response = stdnse.output_table()
  local resultforfile
  if(not(result)) then
    return nil
  end
  if ( not(resp.body) ) then
    return nil
  end


  local vmname = body:match("<name>([^<]*)</name>")
  if not vmname then
    return nil
  end

  local vmversion = body:match("<version>([^<]*)</version>")
  local vmbuild = body:match("<build>([^<]*)</build>")

  if not port.version.product then
    port.version.product = ("%s SOAP API"):format(vmname)
    port.version.version = vmversion
  end
  nmap.set_port_version(host, port, "hardmatched")

  response["Server version"] = ("%s %s build:%s"):format(vmname, vmversion, vmbuild)
  local vctitle = "" .. host.ip .. " ; " .. response["Server version"]
  if (res) then
    response["CVE-2021-21972"] =  "Vulnerable!"
    resultforfile = vctitle.." ; Vulnerable to CVE-2021-21972"
  end
  if ((outputFile) and (resultforfile ~= nil )) then
    file = io.open(outputFile, "a")
    file:write(resultforfile.."\n")
    file.close(file)
  end
  return response
end
