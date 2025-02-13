public with sharing class GlobalPicklistManager {
    @future(callout=true)
    public static void updateGlobalPicklistValues(Set<String> newValues) {
        try {
            // ✅ OAuth 로그인 후 Access Token 및 Instance URL 가져오기
            Map<String, String> authData = MetadataService2.getAccessToken();
            if (authData == null || !authData.containsKey('access_token') || !authData.containsKey('instance_url')) {
                System.debug('❌ OAuth 인증 실패: Access Token 또는 Instance URL을 가져올 수 없습니다.');
                return;
            }

            String accessToken = authData.get('access_token');
            String instanceUrl = authData.get('instance_url');

            // ✅ 올바른 instance_url과 access_token을 사용하여 MetadataPort 생성
            MetadataService2.MetadataPort service = new MetadataService2.MetadataPort(instanceUrl, accessToken);

            String globalValueSetName = 'Brand_Name_List__gvs';  // ✅ Setup에서 확인한 정확한 API Name 사용

            // ✅ 기존 Global Value Set 읽어오기
            MetadataService2.GlobalValueSet gvs = service.readMetadata(globalValueSetName);
            if (gvs == null) {
                System.debug('❌ Global Value Set을 찾을 수 없습니다.');
                return;
            }

            System.debug('✅ Global Value Set 로드 성공: ' + gvs.fullName);

            // ✅ 기존 Picklist 값 유지 & 중복 체크용 Set
            Set<String> existingValues = new Set<String>();
            List<MetadataService2.CustomValue> updatedValues = gvs.customValues; // ✅ 기존 값을 유지

            for (MetadataService2.CustomValue existingValue : gvs.customValues) {
                existingValues.add(existingValue.fullName);
            }

            // ✅ 신규 Picklist 값 추가 (중복 방지)
            for (String newValue : newValues) {
                if (!existingValues.contains(newValue)) {  // ✅ 기존에 없는 값만 추가
                    MetadataService2.CustomValue customValue = new MetadataService2.CustomValue();
                    customValue.fullName = newValue;
                    customValue.label = newValue;
                    customValue.isDefault = false;  // ✅ 기본적으로 활성 상태
                    updatedValues.add(customValue);
                    System.debug('➕ 신규 Picklist 값 추가: ' + newValue);
                }
            }

            // ✅ 기존 값 + 신규 값 병합 후 Metadata 업데이트
            gvs.customValues = updatedValues;  // ✅ 기존 값 유지하면서 추가된 값 반영

            // ✅ Metadata API 호출하여 업데이트
            Boolean success = service.upsertMetadata(gvs);

            if (success) {
                System.debug('✅ Metadata API Picklist 즉시 업데이트 성공!');
            } else {
                System.debug('❌ Metadata API 업데이트 실패');
            }
        } catch (Exception e) {
            System.debug('❌ 예외 발생: ' + e.getMessage());
        }
    }
}
