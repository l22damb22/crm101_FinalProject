public class MetadataService2 {
    // ✅ Salesforce Connected App의 Consumer Key & Secret 설정
    private static final String CLIENT_ID = '3MVG91oqviqJKoEHvQjXeV7UqT.7MtliXXg2mVddHiKS3ClYEyoXmyx9WIGsOPOPz3cx5m9oi10nL5lI5aKtA';
    private static final String CLIENT_SECRET = '59DEFCB698575ED81011BE0625863161901D0F85735ED855CD4E00EBBA95F1A8';
    private static final String USERNAME = 'crm101prj@gmail.com';
    private static final String PASSWORD = 'crm101prjOjtKJ6cLCsK7uHzC9ZD4DAofA';
    private static final String TOKEN_URL = 'https://login.salesforce.com/services/oauth2/token';

    // ✅ OAuth 2.0을 사용하여 Access Token 가져오기
    public static Map<String, String> getAccessToken() {
        try {
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(TOKEN_URL);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/x-www-form-urlencoded');

            String body = 'grant_type=password'
                + '&client_id=' + CLIENT_ID
                + '&client_secret=' + CLIENT_SECRET
                + '&username=' + USERNAME
                + '&password=' + PASSWORD;

            request.setBody(body);
            HttpResponse response = http.send(request);

            if (response.getStatusCode() == 200) {
                Map<String, Object> authResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                
                Map<String, String> result = new Map<String, String>();
                result.put('access_token', (String) authResponse.get('access_token'));
                result.put('instance_url', (String) authResponse.get('instance_url'));

                System.debug('✅ OAuth 인증 성공: ' + JSON.serialize(result));
                return result;
            } else {
                System.debug('❌ OAuth 인증 실패: ' + response.getBody());
                return null;
            }
        } catch (Exception e) {
            System.debug('❌ OAuth 토큰 요청 실패: ' + e.getMessage());
            return null;
        }
    }

    // ✅ Metadata API와 연결하는 MetadataPort 클래스
    public class MetadataPort {
        public String endpoint_x;
        public SessionHeader sessionHeader;

        public MetadataPort(String instance_url, String access_token) {
            this.endpoint_x = instance_url + '/services/Soap/m/59.0';  // ✅ instance_url 사용
            this.sessionHeader = new MetadataService2.SessionHeader();
            this.sessionHeader.sessionId = access_token; // ✅ OAuth Access Token 사용
            System.debug('✅ Metadata API 엔드포인트 설정됨: ' + this.endpoint_x);
        }

        public MetadataService2.GlobalValueSet readMetadata(String globalValueSetName) {
            try {
                Http http = new Http();
                HttpRequest request = new HttpRequest();
                request.setEndpoint(this.endpoint_x);
                request.setMethod('POST');
                request.setHeader('Content-Type', 'text/xml');
                request.setHeader('SOAPAction', '""');
        
                // ✅ SOAP 요청 본문
                String requestBody = '<?xml version="1.0" encoding="UTF-8"?>'
                    + '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">'
                    + '<soapenv:Header>'
                    + '<SessionHeader xmlns="http://soap.sforce.com/2006/04/metadata">'
                    + '<sessionId>' + this.sessionHeader.sessionId + '</sessionId>'
                    + '</SessionHeader>'
                    + '</soapenv:Header>'
                    + '<soapenv:Body>'
                    + '<readMetadata xmlns="http://soap.sforce.com/2006/04/metadata">'
                    + '<type>GlobalValueSet</type>'
                    + '<fullNames>' + globalValueSetName + '</fullNames>'
                    + '</readMetadata>'
                    + '</soapenv:Body>'
                    + '</soapenv:Envelope>';
        
                request.setBody(requestBody);
                HttpResponse response = http.send(request);
        
                System.debug('📦 Metadata API 응답 (readMetadata): ' + response.getBody());
        
                if (response.getStatusCode() == 200) {
                    String responseBody = response.getBody();
                    
                    if (responseBody.contains('<fullName>')) {
                        String fullName = responseBody.substringBetween('<fullName>', '</fullName>');
                        System.debug('✅ GlobalValueSet fullName: ' + fullName);
        
                        MetadataService2.GlobalValueSet gvs = new MetadataService2.GlobalValueSet();
                        gvs.fullName = fullName;
                        gvs.customValues = new List<MetadataService2.CustomValue>();
        
                        // ✅ 기존 Picklist 값 추출 (Deactivated 방지)
                        while (responseBody.contains('<customValue>')) {
                            String customValueXml = responseBody.substringBetween('<customValue>', '</customValue>');
                            
                            System.debug(customValueXml);

                            String valueName = customValueXml.substringBetween('<fullName>', '</fullName>');
                            String label = customValueXml.substringBetween('<label>', '</label>');
                            
                            //String strActive = customValueXml.substringBetween('<isActive>','</isActive>');
                            //Boolean isActive = (strActive.equals('true')) ? true : false; 
                            Boolean isActive = false;    
                            MetadataService2.CustomValue cv = new MetadataService2.CustomValue();
                            cv.fullName = valueName;
                            cv.label = label;
                            cv.isDefault = false;  // ✅ 기본적으로 기존 상태 유지
                            cv.isActive = isActive;  // ✅ 기존 상태 반영
                            if (!isActive) {
                                System.debug('❌ Deactivated 상태 유지: ' + valueName);
                            }
        
                            gvs.customValues.add(cv);
                            
                            responseBody = responseBody.replaceFirst('<customValue>', '');
                        }
        
                        return gvs;
                    } else {
                        System.debug('❌ GlobalValueSet을 찾을 수 없습니다.');
                        return null;
                    }
                } else {
                    System.debug('❌ readMetadata 호출 실패, 응답 코드: ' + response.getStatusCode());
                    return null;
                }
            } catch (Exception e) {
                System.debug('❌ readMetadata 호출 오류: ' + e.getMessage());
                return null;
            }
        }
        

        public Boolean upsertMetadata(MetadataService2.GlobalValueSet gvs) {
            try {
                Http http = new Http();
                HttpRequest request = new HttpRequest();
                request.setEndpoint(this.endpoint_x);
                request.setMethod('POST');
                request.setHeader('Content-Type', 'text/xml');
                request.setHeader('SOAPAction', '""');
        
                // ✅ SOAP XML 요청 생성 (xsi 네임스페이스 추가)
                String requestBody = '<?xml version="1.0" encoding="UTF-8"?>'
                    + '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" '
                    + 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
                    + '<soapenv:Header>'
                    + '<SessionHeader xmlns="http://soap.sforce.com/2006/04/metadata">'
                    + '<sessionId>' + this.sessionHeader.sessionId + '</sessionId>'
                    + '</SessionHeader>'
                    + '</soapenv:Header>'
                    + '<soapenv:Body>'
                    + '<upsertMetadata xmlns="http://soap.sforce.com/2006/04/metadata">'
                    + '<metadata xsi:type="GlobalValueSet">'
                    + '<fullName>' + gvs.fullName + '</fullName>'
                    + '<masterLabel>' + gvs.masterLabel + '</masterLabel>'
                    + '<sorted>' + gvs.sorted + '</sorted>';
        
                for (MetadataService2.CustomValue cv : gvs.customValues) {
                    // ✅ `isDefault` 값이 `null`이면 `false`로 설정                   
                    requestBody += '<customValue>'
                        + '<fullName>' + cv.fullName + '</fullName>'
                        + '<label>' + cv.label + '</label>'
                        + '<default>' + cv.isDefault + '</default>'  // ✅ 확실한 boolean 값 적용
                        + '</customValue>';
                }
        
                requestBody += '</metadata>'
                    + '</upsertMetadata>'
                    + '</soapenv:Body>'
                    + '</soapenv:Envelope>';
        
                request.setBody(requestBody);
                HttpResponse response = http.send(request);
        
                System.debug('📦 Metadata API 응답 (upsertMetadata): ' + response.getBody());
        
                return response.getStatusCode() == 200;
            } catch (Exception e) {
                System.debug('❌ upsertMetadata 호출 오류: ' + e.getMessage());
                return false;
            }
        }
        
    }

    public abstract class Metadata {
        public String fullName;
    }

    public class GlobalValueSet extends Metadata {
        public String masterLabel = 'Brand Name List';
        public Boolean sorted = false;
        public CustomValue[] customValues;
    }

    public class CustomValue {
        public String fullName;
        public String label;
        public Boolean isDefault;  // ✅ 기본값을 false로 설정
        public Boolean isActive;
    }
    

    public class SessionHeader {
        public String sessionId;
    }
}
