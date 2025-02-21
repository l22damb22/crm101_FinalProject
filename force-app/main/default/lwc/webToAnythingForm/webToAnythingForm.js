import { LightningElement, wire, track } from 'lwc';
import { getObjectInfo, createRecord} from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createApplicationForm from '@salesforce/apex/ApplicationFormController.createApplicationForm';
import getLeadById from '@salesforce/apex/ApplicationGetLeadDataController.getLeadById';
import getPicklistValues from '@salesforce/apex/ApplicationFormController.getPicklistValues';
import getCoordinates from '@salesforce/apex/ApplicationFormController.getCoordinates';


export default class WebToAnythingForm extends LightningElement {
    @track isSubmitted = false; // 제출 완료 여부
    @track textContent = '';
    @track brand = '';
    @track name = '';
    @track email = '';
    @track phone = '';
    @track address = '';
    @track detailedAddress = '';
    @track preferredState = '';
    @track preferredDistrict = '';
    @track additionalInfo = '';
    @track zipcode = '';
    @track isDistrictDisabled = true;
    @track isDetailedAddressDisabled = true;
    @track coordinatesLongitude = '';
    @track coordinatesLatitude = '';

    @track isSubmitting = false; // 제출 중 여부
    @track submitButtonLabel = "제출"; // 버튼 라벨

    @track brandOptions = [];
    @track stateOptions = [];
    @track districtOptions = [];
    
    @track selectedControllingValue = '';
    picklistMap = {};

    _leadId;

    connectedCallback() {
        const queryString = window.location.search;
        const urlParams = new URLSearchParams(queryString);
        this.leadId = urlParams.get('leadId') || null; 
        this.loadDaumPostcodeScript();
        //this.loadControllingFieldOptions();
    }
    
    set leadId(value) {
        if (value && value !== this._leadId) {
            this._leadId = value;
            console.log(' Lead ID 변경 감지:', this._leadId);
            this.loadLeadData();
        }else {
            this.isSubmitted = true;
            this.textContent = '작성 권한이 없습니다.';
        }
    }

    get leadId() {
        return this._leadId;
    }

    async loadLeadData() {
        if (!this.leadId ) {
            console.error(' Lead ID 없음');
            return;
        }
        console.log(' Lead ID 있음 ' + this.leadId);
        try {
            const data = await getLeadById({ leadId: this.leadId });
            console.log(' Apex로 가져온 Lead 데이터:', data);
            this.name = data.LastName + (data.FirstName||'');
            this.email = data.Email;
            this.phone = data.Phone;
            this.brand = data.Brand__c;
        } catch (error) {
            console.error(' Lead 데이터 가져오기 실패 (Apex):', error);
        }
    }
    
    //daum 주소 불러오기
    loadDaumPostcodeScript() {
        if (window.daum && window.daum.Postcode) {
            console.log("Daum Postcode API already loaded.");
            return;
        }

        const script = document.createElement("script");
        script.src = "https://t1.daumcdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js";
        script.async = true;
        script.onload = () => console.log("Daum Postcode API loaded.");
        document.head.appendChild(script);
    }

    handleAddressSearch() {
        if (!window.daum || !window.daum.Postcode) {
            console.error("Daum Postcode API not loaded.");
            return;
        }

        new window.daum.Postcode({
            oncomplete: (data) => {
                console.log("주소 검색 결과:", data);
                this.zipcode = data.zonecode;
                this.address = data.roadAddress || data.jibunAddress;
                this.isDetailedAddressDisabled = false;
                this.getCoordinates();
            }

        }).open();
    }

    @wire(getPicklistValues, { objectName: 'Application_Form__c', fieldName: 'Brand_Name__c' })
    wiredBrandPicklistValues({ error, data }) {
        console.log(data);
        if (data) {
            this.brandOptions = data.map(item => ({ label: item, value: item }));
            console.log(data);
        } else if (error) {
            console.error('Picklist 값 가져오기 실패:', error);
        }
    }

    @wire(getPicklistValues, { objectName: 'Application_Form__c', fieldName: 'Preferred_State__c' })
    wiredStatePicklistValues({ error, data }) {
        if (data) {
            this.stateOptions = data.map(item => ({ label: item, value: item }));
            console.log(data);
        } else if (error) {
            console.error('Picklist 값 가져오기 실패:', error);
        }
    }

    districtOptions = {
        '서울특별시': [
            { label: '강남구', value: '강남구' },
            { label: '서초구', value: '서초구' },
            { label: '송파구', value: '송파구' }
        ],
        '부산광역시': [
            { label: '해운대구', value: '해운대구' },
            { label: '부산진구', value: '부산진구' }
        ]
    };

    // 상위(희망 지역) 콤보박스 데이터 가져오기
    @wire(getPicklistValues, { objectName: 'Application_Form__c', fieldName: 'Preferred_State__c' })
    wiredStatePicklistValues({ error, data }) {
        if (data) {
            this.stateOptions = data.map(item => ({ label: item, value: item }));
        } else if (error) {
            console.error('Picklist 값 가져오기 실패:', error);
        }
    }

    // 상위(희망 지역) 콤보박스 값 변경 시 호출
    handleStateChange(event) {
        this.preferredState = event.detail.value;
        this.preferredDistrict = ''; // 하위 값 초기화
        this.isDistrictDisabled = false; // 하위 콤보박스 활성화
        
        // 선택한 지역에 맞는 하위 지역 옵션 가져오기
        this.filteredDistricts = this.districtOptions[this.preferredState] || [];
    }

    // 하위(희망 지역 상세) 콤보박스 값 변경 시 호출
    handleDistrictChange(event) {
        this.preferredDistrict = event.detail.value;
    }
    
    handleChange(event) {
        this[event.target.name] = event.target.value;
    }
    
    handleSubmit() {

    const validationErrors = this.validateInputs();

    if (validationErrors) {
        alert('입력 실패 :\n' + validationErrors.join('\n'));
        return;
    }

    this.isSubmitting = true;
    this.submitButtonLabel = "제출 중..."; // 버튼 변경

    const requestData = {
        leadId: this.leadId,
        name: this.name,
        email: this.email,
        phone: this.phone,
        address: this.address,
        detailedAddress: this.detailedAddress,
        brand: this.brand,
        preferredState: this.preferredState,
        preferredDistrict: this.preferredDistrict,
        additionalInfo: this.additionalInfo,
        coordinatesLongitude : this.coordinatesLongitude,
        coordinatesLatitude : this.coordinatesLatitude
    };

    console.log(requestData);
    createApplicationForm(requestData)
        .then(() => {
            this.isSubmitted = true;
            this.textContent = '🎉 제출이 완료되었습니다!';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: '성공',
                    message: '창업 신청서가 성공적으로 제출되었습니다!',
                    variant: 'success',
                })
            );
            this.resetForm();
        })
        .catch((error) => {
            console.error("Apex 호출 실패:", JSON.stringify(error, null, 2));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: '오류 발생',
                    message: '신청서 제출 중 오류가 발생했습니다. 콘솔을 확인하세요.',
                    variant: 'error',
                })
            );
        })
        .finally(() => {
            this.isSubmitting = false;
            this.submitButtonLabel = "제출"; // 버튼 복구
        });
    }

    //유효성 검증
    validateInputs() {
        let errors = [];
    
        if (!this.name || this.name.trim() === '') {
            errors.push('이름을 입력하세요.');
        }
        if (!this.email || this.email.trim() === '') {
            errors.push('이메일을 입력하세요.');
        }
        if (!this.phone || this.phone.trim() === '') {
            errors.push('전화번호를 입력하세요.');
        }
        if (!this.address || this.address.trim() === '') {
            errors.push('주소를 입력하세요.');
        }
        if (!this.brand || this.brand.trim() === '') {
            errors.push('브랜드를 선택하세요.');
        }
    
        const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (this.email && !emailPattern.test(this.email)) {
            errors.push('올바른 이메일 형식을 입력하세요.');
        }

    
        if (this.coordinatesLongitude && isNaN(this.coordinatesLongitude)|| this.coordinatesLatitude && isNaN(this.coordinatesLatitude)) {
            errors.push('주소값 입력 시 문제가 발생했습니다. 다시 입력해주세요.');
        }

        if (this.additionalInfo && this.additionalInfo.length > 500) {
            errors.push('추가 정보는 최대 200자까지 입력 가능합니다.');
        }
    
        if (!this.preferredState || this.preferredState.trim() === '') {
            errors.push('희망 지역(시/도)을 선택하세요.');
        }
        if (!this.preferredDistrict || this.preferredDistrict.trim() === '') {
            errors.push('희망 지역(구/군)을 선택하세요.');
        }
    
        if (errors.length > 0) {
            console.error(' 입력값 검증 오류:', errors);
            return errors;
        }
    
        console.log('모든 입력값이 올바릅니다.');
        return null;
    }

    
    getCoordinates() {
        let self = this;  
    
        getCoordinates({ address: self.address })  // Apex 메서드 호출
            .then((result) => {  
                let data = JSON.parse(result);
                if (data.documents.length > 0) {
                    self.latitude = data.documents[0].y;  
                    self.longitude = data.documents[0].x;
                    console.log(" 위도:", self.latitude, "경도:", self.longitude);
                    this.coordinatesLongitude = self.longitude;
                    this.coordinatesLatitude = self.latitude;
                } else {
                    console.error("좌표 변환 실패");
                }
            })
            .catch((error) => {
                console.error(" Apex API 호출 실패:", error);
            });
    }
    
    
    resetForm() {
        this.brand = '';
        this.name = '';
        this.email = '';
        this.phone = '';
        this.address = ''; 
        this.detailedAddress = '';
        this.preferredState = '';
        this.preferredDistrict = '';
        this.additionalInfo = '';
        this.zipcode = '';
        this.coordinatesLongitude = '';
        this.coordinatesLatitude = '';
    }

}

//     handleSubmit() {
//         const fields = {};
//         fields[BRAND_FIELD.fieldApiName] = this.brand;
//         fields[NAME_FIELD.fieldApiName] = this.name;
//         fields[EMAIL_FIELD.fieldApiName] = this.email;
//         fields[ADDRESS_FIELD.fieldApiName] = this.address;
//         // fields[DETAILED_ADDRESS_FIELD.fieldApiName] = this.detailedAddress;
//         // fields[STARTUP_REGION_FIELD.fieldApiName] = this.startupRegion;
//         // fields[DETAILED_REGION_FIELD.fieldApiName] = this.detailedStartupRegion;
//         // fields[COORDINATES_FIELD.fieldApiName] = this.coordinates;
//         // Lead ID 필드 검증 후 추가
//         if (this.leadId) {
//             console.log("Lead ID 추가 전:", this.leadId);
//             fields["Lead_Id__c"] = this.leadId;

//         }

//         console.log("📌 최종 필드 데이터:", JSON.stringify(fields));

//         const recordInput = { apiName: APPLICATION_FORM_OBJECT.objectApiName, fields };

//         createRecord(recordInput)
//             .then((record) => {
//                 this.dispatchEvent(
//                     new ShowToastEvent({
//                         title: '성공',
//                         message: '창업 신청서가 성공적으로 제출되었습니다!',
//                         variant: 'success',
//                     })
//                 );
//                 console.log('Record created:', record.id);
//             })
//             .catch((error) => {
//                 console.log("📌 LEAD_ID_FIELD:", LEAD_ID_FIELD.fieldApiName);
//                 console.error('레코드 생성 오류:', JSON.stringify(error, null, 2)); 
//                 this.dispatchEvent(
//                     new ShowToastEvent({
//                         title: '오류 발생',
//                         message: '오류가 발생했습니다. 다시 시도해주세요.',
//                         variant: 'error',
//                     })
//                 );
//                 console.error('Error creating record:', error);
//             });
//     }
// }
