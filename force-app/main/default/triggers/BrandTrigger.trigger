trigger BrandTrigger on Brand__c (after insert) {
    Set<String> brandNames = new Set<String>();
    // 새로 추가된 Brand 레코드에서 brand_name 값 가져오기
    for (Brand__c brand : Trigger.new) {
        if (brand.Name != null) {
            brandNames.add(brand.Name);
        }
    }

    System.debug('brandNames >>> ' + brandNames);
    if (!brandNames.isEmpty()) {
        // Metadata API 호출하여 Global Picklist 업데이트
        GlobalPicklistManager.updateGlobalPicklistValues(brandNames);
    }
}
