public without sharing class ApplicationGetLeadDataController {
    @AuraEnabled(cacheable=true)
    public static Lead getLeadById(Id leadId) {
        try {
            return [
                SELECT LastName, FirstName, Email, Phone, Brand__c
                FROM Lead WHERE Id = :leadId
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Lead 조회 실패: ' + e.getMessage());
        }
    }
}
