public with sharing class GroupingSuggestionController {
    
    @AuraEnabled(cacheable=true)
    public static List<Campaign_Grouping_Suggestion__c> getSuggestions() {
        return [
            SELECT Id, Name, Suggested_Initiative_Name__c, Confidence_Score__c, 
                   Status__c, CreatedDate,
                   (SELECT Id, Campaign__c, Campaign__r.Name, Campaign__r.CreatedDate, 
                           Original_Name__c, Channel_Type__c
                    FROM Campaign_Suggestion_Members__r
                    ORDER BY Campaign__r.CreatedDate)
            FROM Campaign_Grouping_Suggestion__c
            WHERE Status__c = 'Pending Review'
            ORDER BY Confidence_Score__c DESC, CreatedDate DESC
            LIMIT 20
        ];
    }
    
    @AuraEnabled
    public static void approveSuggestion(Id suggestionId) {
        try {
            Campaign_Grouping_Suggestion__c suggestion = [
                SELECT Id, Suggested_Initiative_Name__c, Status__c,
                       (SELECT Campaign__c FROM Campaign_Suggestion_Members__r)
                FROM Campaign_Grouping_Suggestion__c
                WHERE Id = :suggestionId
                LIMIT 1
            ];
            
            if(suggestion.Status__c != 'Pending Review') {
                throw new AuraHandledException('This suggestion has already been processed.');
            }
            
            Campaign parentCampaign = new Campaign(
                Name = suggestion.Suggested_Initiative_Name__c,
                Type = 'Initiative',
                Status = 'In Progress',
                IsActive = true
            );
            insert parentCampaign;
            
            List<Campaign> campaignsToUpdate = new List<Campaign>();
            for(Campaign_Suggestion_Member__c member : suggestion.Campaign_Suggestion_Members__r) {
                campaignsToUpdate.add(new Campaign(
                    Id = member.Campaign__c,
                    ParentId = parentCampaign.Id,
                    Campaign_Initiative__c = parentCampaign.Name
                ));
            }
            
            if(!campaignsToUpdate.isEmpty()) {
                update campaignsToUpdate;
            }
            
            suggestion.Status__c = 'Approved';
            suggestion.Approved_By__c = UserInfo.getUserId();
            suggestion.Approval_Date__c = DateTime.now();
            update suggestion;
            
            CampaignGroupingLearner.learnFromUserAction(suggestionId, 'APPROVED');
            
        } catch(Exception e) {
            throw new AuraHandledException('Error approving suggestion: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void rejectSuggestion(Id suggestionId) {
        try {
            Campaign_Grouping_Suggestion__c suggestion = new Campaign_Grouping_Suggestion__c(
                Id = suggestionId,
                Status__c = 'Rejected',
                Approved_By__c = UserInfo.getUserId(),
                Approval_Date__c = DateTime.now()
            );
            update suggestion;
            
            CampaignGroupingLearner.learnFromUserAction(suggestionId, 'REJECTED');
            
        } catch(Exception e) {
            throw new AuraHandledException('Error rejecting suggestion: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void modifySuggestion(Id suggestionId, String newInitiativeName, List<Id> campaignIds) {
        try {
            Campaign_Grouping_Suggestion__c suggestion = [
                SELECT Id, Status__c
                FROM Campaign_Grouping_Suggestion__c
                WHERE Id = :suggestionId
                LIMIT 1
            ];
            
            if(suggestion.Status__c != 'Pending Review') {
                throw new AuraHandledException('This suggestion has already been processed.');
            }
            
            Campaign parentCampaign = new Campaign(
                Name = newInitiativeName,
                Type = 'Initiative',
                Status = 'In Progress',
                IsActive = true
            );
            insert parentCampaign;
            
            List<Campaign> campaignsToUpdate = new List<Campaign>();
            for(Id campaignId : campaignIds) {
                campaignsToUpdate.add(new Campaign(
                    Id = campaignId,
                    ParentId = parentCampaign.Id,
                    Campaign_Initiative__c = parentCampaign.Name
                ));
            }
            
            if(!campaignsToUpdate.isEmpty()) {
                update campaignsToUpdate;
            }
            
            suggestion.Status__c = 'Modified';
            suggestion.Approved_By__c = UserInfo.getUserId();
            suggestion.Approval_Date__c = DateTime.now();
            update suggestion;
            
            CampaignGroupingLearner.learnFromUserAction(suggestionId, 'MODIFIED');
            
        } catch(Exception e) {
            throw new AuraHandledException('Error modifying suggestion: ' + e.getMessage());
        }
    }
}