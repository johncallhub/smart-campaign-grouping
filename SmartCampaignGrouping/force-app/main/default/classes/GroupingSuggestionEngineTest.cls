@isTest
public class GroupingSuggestionEngineTest {
    
    @TestSetup
    static void setupTestData() {
        List<Campaign> testCampaigns = new List<Campaign>{
            new Campaign(Name = 'CallHub June Rally 2024', Type = 'Outbound', IsActive = true),
            new Campaign(Name = 'Email June Rally Follow-up', Type = 'Email', IsActive = true),
            new Campaign(Name = 'SMS June Rally Reminder', Type = 'SMS', IsActive = true),
            new Campaign(Name = 'Facebook June Rally Event', Type = 'Social', IsActive = true)
        };
        insert testCampaigns;
    }
    
    @isTest
    static void testCreateGroupingSuggestion() {
        List<Campaign> campaigns = [SELECT Id, Name, CreatedDate, CreatedById FROM Campaign];
        
        Test.startTest();
        
        GroupingSuggestionEngine.createGroupingSuggestion('June Rally', campaigns);
        
        Test.stopTest();
        
        List<Campaign_Grouping_Suggestion__c> suggestions = [
            SELECT Id, Suggested_Initiative_Name__c, Confidence_Score__c, Status__c,
                   (SELECT Campaign__c, Original_Name__c, Channel_Type__c 
                    FROM Campaign_Suggestion_Members__r)
            FROM Campaign_Grouping_Suggestion__c
        ];
        
        System.assertEquals(1, suggestions.size(), 'Should create one suggestion');
        
        Campaign_Grouping_Suggestion__c suggestion = suggestions[0];
        System.assertEquals('June Rally', suggestion.Suggested_Initiative_Name__c);
        System.assertEquals('Pending Review', suggestion.Status__c);
        System.assert(suggestion.Confidence_Score__c > 0, 'Should have positive confidence score');
        System.assertEquals(4, suggestion.Campaign_Suggestion_Members__r.size(), 'Should include all campaigns');
        
        Boolean hasEmailChannel = false;
        Boolean hasSMSChannel = false;
        Boolean hasCallChannel = false;
        Boolean hasSocialChannel = false;
        
        for(Campaign_Suggestion_Member__c member : suggestion.Campaign_Suggestion_Members__r) {
            if(member.Channel_Type__c == 'Email') hasEmailChannel = true;
            if(member.Channel_Type__c == 'SMS') hasSMSChannel = true;
            if(member.Channel_Type__c == 'Call') hasCallChannel = true;
            if(member.Channel_Type__c == 'Social Media') hasSocialChannel = true;
        }
        
        System.assert(hasEmailChannel, 'Should detect Email channel');
        System.assert(hasSMSChannel, 'Should detect SMS channel');
        System.assert(hasCallChannel, 'Should detect Call channel');
        System.assert(hasSocialChannel, 'Should detect Social Media channel');
    }
    
    @isTest
    static void testCalculateConfidence() {
        List<Campaign> campaigns = [SELECT Id, Name, CreatedDate, CreatedById FROM Campaign];
        
        Test.startTest();
        
        Decimal confidence = GroupingSuggestionEngine.calculateConfidence(campaigns);
        
        Test.stopTest();
        
        System.assert(confidence > 0, 'Confidence should be positive');
        System.assert(confidence <= 1.0, 'Confidence should not exceed 100%');
    }
    
    @isTest
    static void testDetectChannelType() {
        Test.startTest();
        
        String emailChannel = GroupingSuggestionEngine.detectChannelType('Pardot Email Campaign');
        String smsChannel = GroupingSuggestionEngine.detectChannelType('SMS Text Message Campaign');
        String callChannel = GroupingSuggestionEngine.detectChannelType('CallHub Phone Outreach');
        String socialChannel = GroupingSuggestionEngine.detectChannelType('Facebook Social Media');
        String otherChannel = GroupingSuggestionEngine.detectChannelType('Direct Mail Campaign');
        
        Test.stopTest();
        
        System.assertEquals('Email', emailChannel);
        System.assertEquals('SMS', smsChannel);
        System.assertEquals('Call', callChannel);
        System.assertEquals('Social Media', socialChannel);
        System.assertEquals('Other', otherChannel);
    }
    
    @isTest
    static void testDuplicateSuggestionPrevention() {
        List<Campaign> campaigns = [SELECT Id, Name, CreatedDate, CreatedById FROM Campaign LIMIT 2];
        
        Test.startTest();
        
        GroupingSuggestionEngine.createGroupingSuggestion('June Rally', campaigns);
        GroupingSuggestionEngine.createGroupingSuggestion('June Rally', campaigns);
        
        Test.stopTest();
        
        List<Campaign_Grouping_Suggestion__c> suggestions = [
            SELECT Id FROM Campaign_Grouping_Suggestion__c
            WHERE Suggested_Initiative_Name__c = 'June Rally'
        ];
        
        System.assertEquals(1, suggestions.size(), 'Should not create duplicate suggestions');
    }
    
    @isTest
    static void testAddingCampaignsToExistingSuggestion() {
        List<Campaign> initialCampaigns = [SELECT Id, Name, CreatedDate, CreatedById FROM Campaign LIMIT 2];
        List<Campaign> additionalCampaigns = [SELECT Id, Name, CreatedDate, CreatedById FROM Campaign];
        
        Test.startTest();
        
        GroupingSuggestionEngine.createGroupingSuggestion('June Rally', initialCampaigns);
        GroupingSuggestionEngine.createGroupingSuggestion('June Rally', additionalCampaigns);
        
        Test.stopTest();
        
        List<Campaign_Grouping_Suggestion__c> suggestions = [
            SELECT Id, (SELECT Id FROM Campaign_Suggestion_Members__r)
            FROM Campaign_Grouping_Suggestion__c
            WHERE Suggested_Initiative_Name__c = 'June Rally'
        ];
        
        System.assertEquals(1, suggestions.size(), 'Should have one suggestion');
        System.assertEquals(4, suggestions[0].Campaign_Suggestion_Members__r.size(), 
            'Should include all campaigns in existing suggestion');
    }
    
    @isTest
    static void testEmptyInputHandling() {
        Test.startTest();
        
        GroupingSuggestionEngine.createGroupingSuggestion('', new List<Campaign>());
        GroupingSuggestionEngine.createGroupingSuggestion(null, null);
        GroupingSuggestionEngine.createGroupingSuggestion('Test', new List<Campaign>());
        
        Test.stopTest();
        
        List<Campaign_Grouping_Suggestion__c> suggestions = [
            SELECT Id FROM Campaign_Grouping_Suggestion__c
        ];
        
        System.assertEquals(0, suggestions.size(), 'Should not create suggestions for invalid input');
    }
    
    @isTest
    static void testHighConfidenceScoring() {
        List<Campaign> campaigns = new List<Campaign>();
        
        DateTime baseTime = DateTime.now();
        for(Integer i = 0; i < 3; i++) {
            campaigns.add(new Campaign(
                Name = 'June Rally Campaign ' + i,
                Type = 'Email',
                IsActive = true,
                CreatedDate = baseTime.addMinutes(i * 10)
            ));
        }
        insert campaigns;
        
        campaigns = [SELECT Id, Name, CreatedDate, CreatedById FROM Campaign WHERE Id IN :campaigns];
        
        Test.startTest();
        
        Decimal confidence = GroupingSuggestionEngine.calculateConfidence(campaigns);
        
        Test.stopTest();
        
        System.assert(confidence > 0.5, 'Should have high confidence for similar campaigns created close together');
    }
}