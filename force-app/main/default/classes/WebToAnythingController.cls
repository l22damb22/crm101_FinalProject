public with sharing class WebToAnythingController {
    
    @AuraEnabled
    public static String createApplicationForm(String name, String email, String address, String leadId) {
        try {
            Application_Form__c newApplication = new Application_Form__c();
            newApplication.Name = name;
            newApplication.Email__c = email;
            newApplication.Address__c = address;

            if (leadId != null && leadId != '') {
                newApplication.Lead_Id__c = leadId; // Lookup(Lead) 필드에 저장
            }

            insert newApplication;
            return '신청서가 성공적으로 제출되었습니다.';
        } catch (Exception e) {
            throw new AuraHandledException('오류 발생: ' + e.getMessage());
        }
    }
}