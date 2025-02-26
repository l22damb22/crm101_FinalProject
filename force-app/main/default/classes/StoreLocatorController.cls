public without sharing class StoreLocatorController {
    // 반경 내 상가 업소 조회
    @AuraEnabled
    public static Map<String, String> getStoreListInRadius(String recordId, String radius, String brandName) {

        if (String.isEmpty(brandName)) {
            return new Map<String, String>{ 'error' => 'brandName 값이 없습니다.' };
        }

        Map<String, String> result = new Map<String, String>();
        String indsSclsCd = '';
        // Application_Form__c 레코드가 존재하는지 확인
        Opportunity opptyAccount = [
            SELECT 
            Account.Brand__c, Account.Coordinates__Latitude__s, Account.Coordinates__Longitude__s, 
            Account.Billing_State__c, Account.Billing_District__c, 	Account.Address__c, Account.Detailed_Address__c
            FROM  Opportunity WHERE Id = :recordId
            LIMIT 1
        ];

        if (opptyAccount.Account.Brand__c == '') {
            result.put('error','opptyAccount.Brand__c 레코드 없음');
            return result;
        }

        switch on brandName {
            when '상하이면관' {
                indsSclsCd = 'I20201';
            }
            when '진포차' {
                indsSclsCd = 'I21104';
            }
            when '마을정식' { 
                indsSclsCd = 'I20101';
            }
            when '본스커피' {  
                indsSclsCd = 'I21201';
            }
            when '본스피자' { 
                indsSclsCd = 'I21003';
            }
            when else {
                indsSclsCd = 'I20401'; // 임의로 경양식점 넣어둠
            }
        }

        //indsSclsCd = 'I21201'; //테스트로 임의값
        // 위도, 경도가 null이면 오류 방지
        if (opptyAccount.Account.Coordinates__Latitude__s == null || opptyAccount.Account.Coordinates__Longitude__s == null) {
            System.debug(opptyAccount.Account);
            System.debug('appForm.Coordinates__Latitude__s' + opptyAccount.Account.Coordinates__Latitude__s);
            System.debug('appForm.Coordinates__Longitude__s' + opptyAccount.Account.Coordinates__Longitude__s);
            result.put('error','Invalid Coordinates for given Opportunity_Id');
            return result;
        }
        
        String endpoint = 'callout:SdscAPI/B553077/api/open/sdsc2/storeListInRadius?servicekey=Gk%2BJlJTNBhBabY0UX4gEoS%2BXNYVr84aAd%2B8eUY7RkFqlXVfnFX9R4UdXoWKJ4qZxiJdKUC2g6J5HXQrRiWPZRg%3D%3D'
                         + '&indsSclsCd=' + indsSclsCd
                         + '&cx=' + opptyAccount.Account.Coordinates__Longitude__s
                         + '&cy=' + opptyAccount.Account.Coordinates__Latitude__s
                         + '&radius=' + radius;
        String responseBody = callExternalApi(endpoint);

        if (String.isEmpty(responseBody)) {
            result.put('storeList',null);
            return result;
        }

        // JSON 변환
        String jsonResult = convertXmlToJson(responseBody, 'storeList');

        // JSON 변환 실패 방지
        if (jsonResult == null) {
            result.put('error','파싱 실패');
            return result;
        }
        System.debug('jsonResult >>' + jsonResult);
        //Integer matchingCount = countMatchingStores(jsonResult, '빽');
        Integer matchingCount = countMatchingStores(jsonResult, brandName);
        if (matchingCount == null) {
            matchingCount = 0; // null 방지
        }
       
        result.put('matchingCount', matchingCount +'');
        result.put('jsonResult',jsonResult);
        return result;
    }
    
    // 특정 브랜드와 일치하는 데이터 개수 세는 함수
    private static Integer countMatchingStores(String jsonData, String brandName) {
        Integer count = 0;
        Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(jsonData);
        List<Object> storeList = (List<Object>) jsonMap.get('storeList');

        for (Object store : storeList) {
            Map<String, Object> storeData = (Map<String, Object>) store;
           
            if (storeData.containsKey('bizesNm')) {
                String tempBizesNm = storeData.get('bizesNm').toString();
                System.debug('tempBizesNm >>>' + tempBizesNm);
                if(tempBizesNm.contains(brandName)) count++;
                
            }
        }
        return count;
    }

    // 외부 API 호출 공통 메서드
    private static String callExternalApi(String endpoint) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');

        try {
            HttpResponse response = http.send(request);
            if (response.getStatusCode() == 200) {
                return response.getBody();
            } else {
                System.debug('API 호출 실패: ' + response.getStatus());
                return '{"error": "API call failed with status ' + response.getStatusCode() + '"}';
            }
        } catch (Exception e) {
            System.debug('API 호출 중 오류 발생: ' + e.getMessage());
            return '{"error": "API call encountered an exception"}';
        }
    }

    // XML 데이터를 JSON으로 변환
    private static String convertXmlToJson(String xmlData, String listName) {
        if (String.isEmpty(xmlData)) {
            return null;
        }

        Dom.Document doc = new Dom.Document();

        try {
            doc.load(xmlData);
        } catch (Exception e) {
            System.debug('XML 파싱 오류: ' + e.getMessage());
            return null;
        }

        List<Map<String, String>> resultList = new List<Map<String, String>>();
        Dom.XMLNode root = doc.getRootElement();

        // Null 체크 추가
        if (root == null) {
            return null;
        }

        Dom.XMLNode body = root.getChildElement('body', null);
        if (body == null) {
            return null;
        }

        Dom.XMLNode items = body.getChildElement('items', null);
        if (items == null) {
            return null;
        }

        for (Dom.XMLNode item : items.getChildElements()) {
            Map<String, String> record = new Map<String, String>();
            for (Dom.XMLNode child : item.getChildElements()) {
                record.put(child.getName(), child.getText());
            }
            resultList.add(record);
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put(listName, resultList);
        return JSON.serialize(result);
    }

    //appForm 정보 불러오기
    @AuraEnabled(cacheable=true)
    public static Application_Form__c getAppForm(Id opptyId) {
        try {
            return [
                SELECT 
                        Brand_Name__c, Coordinates__Latitude__s, Coordinates__Longitude__s, Opportunity_Id__c,
                        Preferred_State__c, Preferred_District__c, 	Address__c, Detailed_Address__c
                FROM  Application_Form__c WHERE Opportunity_Id__c = :opptyId
            ];
        } catch (Exception e) {
            throw new AuraHandledException('창업신청서 조회 실패: ' + e.getMessage());
        }
    }
    
    //appForm >> 변경! account 정보 불러오기
    @AuraEnabled(cacheable=true)
    public static Opportunity getAccnt(Id opptyId) {
        try {
            return [
                SELECT 
                    Id, Account.Brand__c, Account.Coordinates__Latitude__s, Account.Coordinates__Longitude__s,
                    Account.Billing_State__c, Account.Billing_District__c, 	Account.Address__c, Account.Detailed_Address__c
                FROM  Opportunity WHERE Id = :opptyId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('account 계정정보 조회 실패: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Account> getAccList(String billingState, String billingDistrict, String brand) {
        try {
            List<Account> accounts = [
                SELECT Name, Id FROM Account 
                WHERE Billing_State__c = :billingState AND Billing_District__c = :billingDistrict
                AND Active__c = 'Yes' AND Brand__c = :brand
            ];
            return accounts; 
        } catch (Exception e) {
            throw new AuraHandledException('Account 조회 실패: ' + e.getMessage());
        }
    }

  
    @AuraEnabled
    public static String updateRecord(Id recordId, String brandName, String preferredState, String preferredDistrict) {
        try {
            // 레코드 조회
            Application_Form__c appForm = [SELECT Id, Brand_Name__c, Preferred_State__c, Preferred_District__c
                                           FROM Application_Form__c
                                           WHERE Id = :recordId LIMIT 1];

            // 필드 업데이트
            if (brandName != null) appForm.Brand_Name__c = brandName;
            if (preferredState != null) appForm.Preferred_State__c = preferredState;
            if (preferredDistrict != null) appForm.Preferred_District__c = preferredDistrict;
            
            // 업데이트 수행
            update appForm;

            return 'updateRecord 완료.';
        } catch (Exception e) {
            return '실패: ' + e.getMessage();
        }
    }
}
