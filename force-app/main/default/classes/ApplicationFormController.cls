public with sharing class ApplicationFormController {

    private static final String CLIENT_ID = '3MVG91oqviqJKoEHvQjXeV7UqT.7MtliXXg2mVddHiKS3ClYEyoXmyx9WIGsOPOPz3cx5m9oi10nL5lI5aKtA';
    private static final String CLIENT_SECRET = '59DEFCB698575ED81011BE0625863161901D0F85735ED855CD4E00EBBA95F1A8';
    private static final String USERNAME = 'crm101prj@gmail.com';
    private static final String PASSWORD = 'crm101prjOjtKJ6cLCsK7uHzC9ZD4DAofA';
    private static final String TOKEN_URL = 'https://login.salesforce.com/services/oauth2/token';


    @AuraEnabled
    public static Id createApplicationForm(String leadId, String name, String email, String phone, String address, 
                                           String detailedAddress, String brand, String preferredState, String preferredDistrict, String additionalInfo) {
        try {
            Application_Form__c newForm = new Application_Form__c(
                Lead_Id__c = leadId,
                Name = name,
                Email__c = email, // 이메일
                Phone__c = phone, // 전화번호
                Address__c = address, // 주소
                Detailed_Address__c = detailedAddress, // 상세 주소
                Brand_Name__c = brand, // 브랜드명
                Preferred_State__c = preferredState, // 창업 희망 지역
                Preferred_District__c = preferredDistrict, // 창업 희망 지역 상세
                Additional_Information__c = additionalInfo
            );

            insert newForm;
            System.debug('[SUCCESS] 신청서 생성 성공, ID: ' + newForm.Id);
            return newForm.Id;
        } catch (Exception e) {
            System.debug('[ERROR] 신청서 생성 실패: ' + e.getMessage());
            throw new AuraHandledException('오류 발생: ' + e.getMessage());
        }
    }

    //필드 픽리스트 값 가져오기
    @AuraEnabled(cacheable=true)
    public static List<String> getPicklistValues(String objectName, String fieldName) {
        List<String> picklistValues = new List<String>();

        try {
            // 특정 오브젝트의 필드 정보 가져오기
            Schema.DescribeFieldResult fieldResult = Schema.getGlobalDescribe().get(objectName)
                .getDescribe().fields.getMap().get(fieldName).getDescribe();

            List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();

            // Picklist 값 추출
            for (Schema.PicklistEntry entry : picklistEntries) {
                picklistValues.add(entry.getLabel()); // Label 값 반환
            }
        } catch (Exception e) {
            System.debug('Error fetching Picklist values: ' + e.getMessage());
        }

        return picklistValues;
    }


    @AuraEnabled(cacheable=true)
    public static String getSpecificPicklistValuesWithoutRecordType() {

        Map<String, String> token = MetadataService2.getAccessToken();
        String instanceUrl = token.get('instance_url');
        String accessToken = token.get('access_token');

        // ✅ 레코드 타입 없이 Picklist 값 가져오기
        String apiUrl = instanceUrl + '/services/data/v59.0/ui-api/object-info/Application_Form__c/picklist-values/field/Preferred_State__c';
        System.debug('✅ API URL: ' + apiUrl);

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(apiUrl);
        request.setMethod('GET');
        request.setHeader('Authorization', 'Bearer ' + accessToken);
        request.setHeader('Content-Type', 'application/json');

        HttpResponse response = http.send(request);
        System.debug('✅ Response Status: ' + response.getStatusCode());

        if (response.getStatusCode() == 200) {
            System.debug('✅ Response Body: ' + response.getBody());
            return response.getBody();
        } else {
            System.debug('❌ Error Response: ' + response.getBody());
            throw new CalloutException('Failed to fetch picklist values: ' + response.getStatus());
        }
    }

}
