@RestResource(urlMapping='/storelocator/getStores')
global without sharing class StoreLocatorControllerForVF {

    @HttpGet
    global static String getStoreListInRadius() {
        RestRequest req = RestContext.request;
        String recordId = req.params.get('recordId');
        String radius = req.params.get('radius');

        if (String.isEmpty(recordId)) {
            return '{ "error": "recordId 없음" }';
        }

        Opportunity opptyAccount;
        try {
            opptyAccount = [
                SELECT Account.Brand__c, Account.Coordinates__Latitude__s, Account.Coordinates__Longitude__s
                FROM Opportunity 
                WHERE Id = :recordId
                LIMIT 1
            ];
        } catch (Exception e) {
            return '{"error": "데이터 조회 실패: ' + String.escapeSingleQuotes(e.getMessage()) + '"}';
        }

        if (opptyAccount == null || opptyAccount.Account.Brand__c == null) {
            return '{ "error": "Brand 정보 없음" }';
        }

        if (opptyAccount.Account.Coordinates__Latitude__s == null || opptyAccount.Account.Coordinates__Longitude__s == null) {
            return '{ "error": "Invalid Coordinates for given Opportunity_Id" }';
        }

        // Decimal 값을 String으로 변환 후 URL 인코딩 적용
        String latitude = EncodingUtil.urlEncode(String.valueOf(opptyAccount.Account.Coordinates__Latitude__s), 'UTF-8');
        String longitude = EncodingUtil.urlEncode(String.valueOf(opptyAccount.Account.Coordinates__Longitude__s), 'UTF-8');
        String encodedRadius = EncodingUtil.urlEncode(radius, 'UTF-8');

        String endpoint = 'https://bigdata.sbiz.or.kr/pub/api/apics/storeListInRadius'
                        + '?cx=' + longitude
                        + '&cy=' + latitude
                        + '&radius=' + encodedRadius;

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setTimeout(60000);
        request.setHeader('Authorization', 'x815c5fy3h');

        HttpResponse response;
        try {
            response = http.send(request);
        } catch (Exception e) {
            return '{"error": "외부 API 호출 실패: ' + String.escapeSingleQuotes(e.getMessage()) + '"}';
        }

        String responseBody = response.getBody();

        if (responseBody.startsWith('<!DOCTYPE') || response.getStatusCode() != 200) {
            return '{ "error": "API 호출 실패 (' + response.getStatusCode() + ')" }';
        }

        return responseBody;
    }
}
