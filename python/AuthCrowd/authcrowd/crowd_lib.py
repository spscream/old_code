from trac.core import *

import re
import cgi
import wsgiref.handlers
import os
import httplib
import logging
from datetime import datetime, timedelta

try:
    from xml.etree import cElementTree as ElementTree
except ImportError:
    import cElementTree as ElementTree

from soaplib.wsgi_soap import SimpleWSGISoapApp
from soaplib.service import soapmethod
import soaplib.serializers.primitive
from soaplib.serializers.primitive import _unicode_to_xml, String, _element_to_unicode, Integer, Boolean, DateTime, Array
from soaplib.client import make_service_client
from soaplib.serializers.clazz import ClassSerializer

class NewString:    
    @classmethod
    def to_xml(cls, value, name='retval'):
        e = _unicode_to_xml(value,name,cls.get_datatype(True))
        e.set('xmlns','http://authentication.integration.crowd.atlassian.com')
        return e
    @classmethod
    def from_xml(cls,element):
        return _element_to_unicode(element)

    @classmethod
    def get_datatype(cls,withNamespace=False):
        if withNamespace:
            return 'xs:string'
        return 'string'

    @classmethod
    def add_to_schema(cls,added_params):
        pass

class NewArray:
    
    def __init__(self,serializer,type_name=None,namespace='tns'):
        self.serializer = serializer
        self.namespace = namespace
        if not type_name:
            self.type_name = '%sArray'%self.serializer.get_datatype()
        else:
            self.type_name = type_name

    def to_xml(self,values,name='retval'):
        res = ElementTree.Element(name)
        typ = self.get_datatype(True)
        res.set('xmlns','http://authentication.integration.crowd.atlassian.com') 
        if values == None:
            values = []
        res.set('xsi:type',self.get_datatype(True))
        for value in values:
            serializer = self.serializer
            if value == None:
                serializer = Null
            res.append(
                serializer.to_xml(value,name=serializer.get_datatype(False))
            )
        return res    

    def from_xml(self,element):
        results = []
        for child in element.getchildren():
            results.append(self.serializer.from_xml(child))
        return results

    def get_datatype(self,withNamespace=False):
        if withNamespace:
            return '%s:%s'%(self.namespace,self.type_name)
        return self.type_name

    def add_to_schema(self,schema_dict):
        typ = self.get_datatype()
        
        self.serializer.add_to_schema(schema_dict)

        if not schema_dict.has_key(typ):

            complexTypeNode = ElementTree.Element("xs:complexType")
            complexTypeNode.set('name',self.get_datatype(False))

            sequenceNode = ElementTree.SubElement(complexTypeNode, 'xs:sequence')
            elementNode = ElementTree.SubElement(sequenceNode, 'xs:element')
            elementNode.set('minOccurs','0')
            elementNode.set('maxOccurs','unbounded')
            elementNode.set('type',self.serializer.get_datatype(True))
            elementNode.set('name',self.serializer.get_datatype(False))

            typeElement = ElementTree.Element("xs:element")            
            typeElement.set('name',typ)
            typeElement.set('type',self.get_datatype(True))
            
            schema_dict['%sElement'%(self.get_datatype(True))] = typeElement
            schema_dict[self.get_datatype(True)] = complexTypeNode
            
class ValidationFactor(ClassSerializer):
    class types:
        name = NewString
        value = NewString
    
class PasswordCredential(ClassSerializer):
    class types:
        credential = NewString
        _namespace_ = 'http://authentication.integration.crowd.atlassian.com'

class ApplicationAuthenticationContext(ClassSerializer):
    class types:
        credential = PasswordCredential
        name = NewString
        _namespace_ = 'http://authentication.integration.crowd.atlassian.com'

        
class AuthenticatedToken(ClassSerializer):
    class types:
        name = NewString
        token = NewString
        
class PrincipalAuthenticationContext(ClassSerializer):
    class types:
        application = NewString
        credential = PasswordCredential
        name = NewString
        validationFactors = NewArray(ValidationFactor)
        _namespace_ = 'http://authentication.integration.crowd.atlassian.com'
        
class SOAPAttribute(ClassSerializer):
    class types:
        name = NewString
        values = Array(NewString)
        
class SOAPPrincipal(ClassSerializer):
    class types:
        ID = Integer
        name = NewString
        directoryID = Integer
        active = Boolean
        conception = DateTime
        description = NewString
        lastModified = DateTime
        attributes = Array(SOAPAttribute)

class SecurityServer(SimpleWSGISoapApp):
    __tns__ = 'urn:SecurityServer'

    @soapmethod(    ApplicationAuthenticationContext,
                    _returns=AuthenticatedToken,
                    _inMessage='authenticateApplication',
                    _outMessage='authenticateApplicationResponse',
                    _outVariableName='out')
    def authenticateApplication(self,in0):
        pass
    @soapmethod(    AuthenticatedToken,
                    PrincipalAuthenticationContext,
                    _returns=NewString,
                    _inMessage='authenticatePrincipal',
                    _outMessage='authenticatePrincipalResponse',
                    _outVariableName='out')
    def authenticatePrincipal(self,in0,in1):
        pass
    @soapmethod(    AuthenticatedToken,
                    NewString,
                    _returns=SOAPPrincipal,
                    _inMessage='findPrincipalByToken',
                    _outMessage='findPrincipalByTokenResponse',
                    _outVariableName='out')
    def findPrincipalByToken(self,in0,in1):
        pass
    @soapmethod(    AuthenticatedToken,
		    NewString,
		    _returns=SOAPPrincipal,
		    _inMessage='findPrincipalByName',
		    _outMessage='findPrincipalByNameResponse',
		    _outVariableName='out')
    def findPrincipalByName(self,in0,in1):
	pass
    @soapmethod(    AuthenticatedToken,
		    _returns=Array(String),
		    _inMessage='findAllPrincipalNames',
		    _outMessage='findAllPrincipalNamesResponse',
		    _outVariableName='out')
    def findAllPrincipalNames(self,in0):
	pass
    @soapmethod(    AuthenticatedToken,
                    NewString,
                    Array(ValidationFactor),
                    _returns=Boolean,
                    _inMessage='isValidPrincipalToken',
                    _outMessage='isValidPrincipalTokenResponse',
                    _outVariableName='out')
    def isValidPrincipalToken(self,in0,in1,in2):
        pass
    @soapmethod(    AuthenticatedToken,
                    NewString,
                    _returns=None,
                    _inMessage='invalidatePrincipalToken',
                    _outMessage='invalidatePrincipalTokenResponse',
                    _outVariableName='out')
    def invalidatePrincipalToken(self,in0,in1):
        pass
    
class Crowd(object):
    def __init__(self, path, applicationName, applicationPassword, clientValidationInterval):
        self.client = make_service_client(path + '/crowd/services/SecurityServer',SecurityServer())
        self.applicationName = applicationName
        self.applicationPassword = applicationPassword
        self.clientValidationInterval = clientValidationInterval
        
    def getValidationFactors(self,request):
        remoteAddress = ValidationFactor()
        remoteAddress.name = 'remote_address'
        remoteAddress.value = cgi.escape(os.environ["REMOTE_ADDR"])
        userAgent = ValidationFactor()
        userAgent.name = 'User-Agent'
        userAgent.value = request.headers['User-Agent']
        return [remoteAddress, userAgent]

    def userlist(self):
	appToken = self.newAppToken();
	try:
	    users = []
	    for user in self.client.findAllPrincipalNames(appToken):
		users.append(user.lower())
	    return users
	except Exception, e:
	    return []
    
    def auth(self, username, password):
	appToken = self.newAppToken();
	principalAuthContext = PrincipalAuthenticationContext()
        principalAuthContext.application = self.applicationName
	principalCredential = PasswordCredential()
        principalCredential.credential = password
        principalAuthContext.credential = principalCredential
        principalAuthContext.name = username
        cookie = self.client.authenticatePrincipal(appToken, principalAuthContext)
	return cookie

    def user_details(self, username):
	appToken = self.newAppToken();
	details = []
	try:
	    soapPrincipal = self.client.findPrincipalByName(appToken,username)
	    details = soapPrincipal.attributes
	    return details
	except Exception,e:
	    return []

    
    def user_groups(self, username):
	DN_RE = re.compile(r'^(?P<attr>.+?)=(?P<rdn>.+?),(?P<base>.+)$')
	GROUP_PREFIX = '@'
	appToken = self.newAppToken();
	groups = []
	try:
	    soapPrincipal = self.client.findPrincipalByName(appToken,username)
	    for i in soapPrincipal.attributes[1].values:
		m = DN_RE.search(i)
		if m:
		    groups.append(GROUP_PREFIX + m.group('rdn'))
	    return groups
	except Exception,e:
	    return []
	
									
    
    def getAppToken(self):
        applicationAuth = CachedApplicationAuthentication.gql("where applicationName = :name", name = self.applicationName).get()
        if applicationAuth:
            authenticatedToken = AuthenticatedToken()
            authenticatedToken.token = applicationAuth.token
            authenticatedToken.name = self.applicationName
            return authenticatedToken
        else:
            return self.newAppToken()
        
    def newAppToken(self):
        pw = PasswordCredential()
        pw.credential = self.applicationPassword
        authContext = ApplicationAuthenticationContext()
        authContext.credential = pw;
        authContext.name = self.applicationName
        authenticatedToken = self.client.authenticateApplication(authContext)
        return authenticatedToken
    
    def getCurrentUser(self,request):
        return self.doWithAppToken(self._getCurrentUser, request)
        
    def _getCurrentUser(self, request, token):
        if not request.cookies.has_key('crowd.token_key'):
            return None
        else:
            cookie = request.cookies['crowd.token_key']
            # first check whether the cookie has been validated recently
            currentPrincipalAuthentication = CachedPrincipalAuthentication.gql("where cookie = :c", c = cookie).get()
            if currentPrincipalAuthentication and not currentPrincipalAuthentication.timedOut(self.clientValidationInterval * 1000000):
                return currentPrincipalAuthentication.username
            if self.client.isValidPrincipalToken(self.getAppToken(),cookie,self.getValidationFactors(request)):
                soapPrincipal = self.client.findPrincipalByToken(self.getAppToken(),cookie)
                logging.debug("got SOAPPrincipal: %s", soapPrincipal.name)
                if currentPrincipalAuthentication:
                    currentPrincipalAuthentication.validationDate = datetime.today()
                else:
                    currentPrincipalAuthentication = CachedPrincipalAuthentication()
                    currentPrincipalAuthentication.cookie = cookie
                    currentPrincipalAuthentication.username = soapPrincipal.name
                    logging.debug("No record found for cookie %s", cookie)
                currentPrincipalAuthentication.put()
                
                return soapPrincipal.name
            else:
                return None
            
    def logout(self,request):
        self.doWithAppToken(self._logout, request)
        
    def _logout(self, request, token):
        if request.cookies.has_key('crowd.token_key'):
            cookie = request.cookies['crowd.token_key']
            self.client.invalidatePrincipalToken(token,cookie)
            currentPrincipalAuthentication = CachedPrincipalAuthentication.gql("where cookie = :c", c = cookie).get()
            if currentPrincipalAuthentication:
                currentPrincipalAuthentication.delete()
            
    
    def doWithAppToken(self, f, request):
        try:
            return f(request, self.getAppToken())
        except Exception, e:
            logging.debug('Got exception %s', e)
            return f(request, self.newAppToken())
        
    
