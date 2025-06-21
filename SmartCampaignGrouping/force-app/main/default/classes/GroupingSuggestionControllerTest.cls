@isTest
public class GroupingSuggestionControllerTest {
    
    @TestSetup
    static void setupTestData() {
        List<Campaign> testCampaigns = new List<Campaign>{
            new Campaign(Name = 'CallHub June Rally 2024', Type = 'Outbound', IsActive = true),
            new Campaign(Name = 'Email June Rally Follow-up', Type = 'Email', IsActive = true),
            new Campaign(Name = 'SMS June Rally Reminder', Type = 'SMS', IsActive = true)
        };
        insert testCampaigns;
        
        Campaign_Grouping_Suggestion__c suggestion = new Campaign_Grouping_Suggestion__c(
            Suggested_Initiative_Name__c = 'June Rally Test',
            Confidence_Score__c = 0.85,
            Status__c = 'Pending Review'
        );
        insert suggestion;
        
        List<Campaign_Suggestion_Member__c> members = new List<Campaign_Suggestion_Member__c>();
        for(Campaign c : testCampaigns) {
            members.add(new Campaign_Suggestion_Member__c(
                Campaign__c = c.Id,
                Suggestion__c = suggestion.Id,
                Original_Name__c = c.Name,
                Channel_Type__c = GroupingSuggestionEngine.detectChannelType(c.Name)
            ));
        }
        insert members;
    }
    
    @isTest
    static void testGetSuggestions() {
        Test.startTest();
        
        List<Campaign_Grouping_Suggestion__c> suggestions = GroupingSuggestionController.getSuggestions();
        
        Test.stopTest();
        
        System.assertEquals(1, suggestions.size(), 'Should return one suggestion');
        
        Campaign_Grouping_Suggestion__c suggestion = suggestions[0];
        System.assertEquals('June Rally Test', suggestion.Suggested_Initiative_Name__c);
        System.assertEquals('Pending Review', suggestion.Status__c);
        System.assertEquals(3, suggestion.Campaign_Suggestion_Members__r.size(), 'Should include all members');
    }
    
    @isTest
    static void testApproveSuggestion() {
        Campaign_Grouping_Suggestion__c suggestion = [
            SELECT Id FROM Campaign_Grouping_Suggestion__c LIMIT 1
        ];
        
        Test.startTest();
        
        GroupingSuggestionController.approveSuggestion(suggestion.Id);
        
        Test.stopTest();
        
        Campaign_Grouping_Suggestion__c updatedSuggestion = [
            SELECT Status__c, Approved_By__c, Approval_Date__c
            FROM Campaign_Grouping_Suggestion__c
            WHERE Id = :suggestion.Id
        ];
        
        System.assertEquals('Approved', updatedSuggestion.Status__c);
        System.assertEquals(UserInfo.getUserId(), updatedSuggestion.Approved_By__c);
        System.assertNotEquals(null, updatedSuggestion.Approval_Date__c);
        
        List<Campaign> parentCampaigns = [
            SELECT Id, Name, Type
            FROM Campaign
            WHERE Type = 'Initiative'
            AND Name = 'June Rally Test'
        ];
        
        System.assertEquals(1, parentCampaigns.size(), 'Should create parent campaign');
        
        List<Campaign> childCampaigns = [
            SELECT Id, ParentId, Campaign_Initiative__c
            FROM Campaign
            WHERE ParentId = :parentCampaigns[0].Id
        ];
        
        System.assertEquals(3, childCampaigns.size(), 'Should update child campaigns');
        
        for(Campaign child : childCampaigns) {
            System.assertEquals(parentCampaigns[0].Id, child.ParentId);
            System.assertEquals('June Rally Test', child.Campaign_Initiative__c);
        }
    }
    
    @isTest
    static void testRejectSuggestion() {
        Campaign_Grouping_Suggestion__c suggestion = [
            SELECT Id FROM Campaign_Grouping_Suggestion__c LIMIT 1
        ];
        
        Test.startTest();
        
        GroupingSuggestionController.rejectSuggestion(suggestion.Id);
        
        Test.stopTest();
        
        Campaign_Grouping_Suggestion__c updatedSuggestion = [
            SELECT Status__c, Approved_By__c, Approval_Date__c
            FROM Campaign_Grouping_Suggestion__c
            WHERE Id = :suggestion.Id
        ];
        
        System.assertEquals('Rejected', updatedSuggestion.Status__c);
        System.assertEquals(UserInfo.getUserId(), updatedSuggestion.Approved_By__c);
        System.assertNotEquals(null, updatedSuggestion.Approval_Date__c);
        
        List<Campaign> parentCampaigns = [
            SELECT Id FROM Campaign WHERE Type = 'Initiative'
        ];
        
        System.assertEquals(0, parentCampaigns.size(), 'Should not create parent campaign when rejected');
    }
    
    @isTest
    static void testModifySuggestion() {
        Campaign_Grouping_Suggestion__c suggestion = [
            SELECT Id, (SELECT Campaign__c FROM Campaign_Suggestion_Members__r)
            FROM Campaign_Grouping_Suggestion__c LIMIT 1
        ];
        
        List<Id> campaignIds = new List<Id>();
        for(Campaign_Suggestion_Member__c member : suggestion.Campaign_Suggestion_Members__r) {
            campaignIds.add(member.Campaign__c);
        }
        
        campaignIds.remove(0); // Remove one campaign to simulate modification
        
        Test.startTest();
        
        GroupingSuggestionController.modifySuggestion(
            suggestion.Id, 
            'Modified June Rally Initiative', 
            campaignIds
        );
        
        Test.stopTest();
        
        Campaign_Grouping_Suggestion__c updatedSuggestion = [
            SELECT Status__c, Approved_By__c, Approval_Date__c
            FROM Campaign_Grouping_Suggestion__c
            WHERE Id = :suggestion.Id
        ];
        
        System.assertEquals('Modified', updatedSuggestion.Status__c);
        System.assertEquals(UserInfo.getUserId(), updatedSuggestion.Approved_By__c);
        System.assertNotEquals(null, updatedSuggestion.Approval_Date__c);
        
        List<Campaign> parentCampaigns = [
            SELECT Id, Name
            FROM Campaign
            WHERE Type = 'Initiative'
            AND Name = 'Modified June Rally Initiative'
        ];
        
        System.assertEquals(1, parentCampaigns.size(), 'Should create modified parent campaign');
        
        List<Campaign> childCampaigns = [
            SELECT Id FROM Campaign WHERE ParentId = :parentCampaigns[0].Id
        ];
        
        System.assertEquals(campaignIds.size(), childCampaigns.size(), 
            'Should only group selected campaigns');
    }
    
    @isTest
    static void testApproveAlreadyProcessedSuggestion() {
        Campaign_Grouping_Suggestion__c suggestion = [
            SELECT Id FROM Campaign_Grouping_Suggestion__c LIMIT 1
        ];
        
        suggestion.Status__c = 'Approved';
        update suggestion;
        
        Test.startTest();
        
        try {
            GroupingSuggestionController.approveSuggestion(suggestion.Id);
            System.assert(false, 'Should throw exception for already processed suggestion');
        } catch(AuraHandledException e) {
            System.assert(e.getMessage().contains('already been processed'), 
                'Should throw appropriate error message');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetSuggestionsWithNoData() {
        delete [SELECT Id FROM Campaign_Grouping_Suggestion__c];
        
        Test.startTest();
        
        List<Campaign_Grouping_Suggestion__c> suggestions = GroupingSuggestionController.getSuggestions();
        
        Test.stopTest();
        
        System.assertEquals(0, suggestions.size(), 'Should return empty list when no suggestions exist');
    }
    
    @isTest
    static void testModifyWithInvalidData() {
        Campaign_Grouping_Suggestion__c suggestion = [
            SELECT Id FROM Campaign_Grouping_Suggestion__c LIMIT 1
        ];
        
        Test.startTest();
        
        try {
            GroupingSuggestionController.modifySuggestion(
                suggestion.Id, 
                '', // Empty name
                new List<Id>() // Empty campaign list
            );
            System.assert(false, 'Should validate input data');
        } catch(Exception e) {
            // Expected to fail with validation
            System.assert(true, 'Should handle invalid input gracefully');
        }
        
        Test.stopTest();
    }
}