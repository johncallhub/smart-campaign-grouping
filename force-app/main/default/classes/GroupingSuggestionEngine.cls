public class GroupingSuggestionEngine {
    
    public static void createGroupingSuggestion(String pattern, List<Campaign> campaigns) {
        if(String.isBlank(pattern) || campaigns == null || campaigns.isEmpty()) {
            return;
        }
        
        List<Campaign_Grouping_Suggestion__c> existingSuggestions = [
            SELECT Id, (SELECT Campaign__c FROM Campaign_Suggestion_Members__r)
            FROM Campaign_Grouping_Suggestion__c
            WHERE Suggested_Initiative_Name__c = :pattern
            AND Status__c = 'Pending Review'
            LIMIT 1
        ];
        
        Set<Id> existingCampaignIds = new Set<Id>();
        if(!existingSuggestions.isEmpty()) {
            for(Campaign_Suggestion_Member__c member : existingSuggestions[0].Campaign_Suggestion_Members__r) {
                existingCampaignIds.add(member.Campaign__c);
            }
        }
        
        Campaign_Grouping_Suggestion__c suggestion;
        if(existingSuggestions.isEmpty()) {
            suggestion = new Campaign_Grouping_Suggestion__c(
                Suggested_Initiative_Name__c = pattern,
                Confidence_Score__c = calculateConfidence(campaigns),
                Status__c = 'Pending Review'
            );
            insert suggestion;
        } else {
            suggestion = existingSuggestions[0];
        }
        
        List<Campaign_Suggestion_Member__c> newMembers = new List<Campaign_Suggestion_Member__c>();
        for(Campaign c : campaigns) {
            if(!existingCampaignIds.contains(c.Id)) {
                newMembers.add(new Campaign_Suggestion_Member__c(
                    Campaign__c = c.Id,
                    Suggestion__c = suggestion.Id,
                    Original_Name__c = c.Name,
                    Channel_Type__c = detectChannelType(c.Name)
                ));
            }
        }
        
        if(!newMembers.isEmpty()) {
            insert newMembers;
            
            if(existingSuggestions.isEmpty()) {
                sendSuggestionNotification(suggestion, campaigns);
            }
        }
    }
    
    @TestVisible
    private static Decimal calculateConfidence(List<Campaign> campaigns) {
        if(campaigns == null || campaigns.size() < 2) {
            return 0;
        }
        
        Decimal score = 0;
        
        score += calculateNameSimilarity(campaigns) * 0.4;
        score += calculateTemporalProximity(campaigns) * 0.3;
        score += calculateChannelDiversity(campaigns) * 0.2;
        score += calculateCreatorDiversity(campaigns) * 0.1;
        
        return Math.min(score, 1.0);
    }
    
    private static Decimal calculateNameSimilarity(List<Campaign> campaigns) {
        if(campaigns.size() < 2) return 0;
        
        Set<String> commonWords = new Set<String>();
        Map<String, Integer> wordCount = new Map<String, Integer>();
        
        for(Campaign c : campaigns) {
            List<String> words = c.Name.toLowerCase().split('\\s+');
            Set<String> uniqueWords = new Set<String>();
            
            for(String word : words) {
                if(word.length() > 3 && !isChannelIndicator(word)) {
                    uniqueWords.add(word);
                    Integer count = wordCount.containsKey(word) ? wordCount.get(word) : 0;
                    wordCount.put(word, count + 1);
                }
            }
        }
        
        Integer matchingWords = 0;
        for(String word : wordCount.keySet()) {
            if(wordCount.get(word) >= campaigns.size() * 0.7) {
                matchingWords++;
            }
        }
        
        return matchingWords > 0 ? Math.min(matchingWords * 0.3, 1.0) : 0;
    }
    
    private static Decimal calculateTemporalProximity(List<Campaign> campaigns) {
        if(campaigns.size() < 2) return 0;
        
        DateTime minDate = campaigns[0].CreatedDate;
        DateTime maxDate = campaigns[0].CreatedDate;
        
        for(Campaign c : campaigns) {
            if(c.CreatedDate < minDate) minDate = c.CreatedDate;
            if(c.CreatedDate > maxDate) maxDate = c.CreatedDate;
        }
        
        Long hoursDiff = (maxDate.getTime() - minDate.getTime()) / (1000 * 60 * 60);
        
        if(hoursDiff <= 24) return 1.0;
        if(hoursDiff <= 48) return 0.8;
        if(hoursDiff <= 168) return 0.6;
        if(hoursDiff <= 336) return 0.4;
        
        return 0.2;
    }
    
    private static Decimal calculateChannelDiversity(List<Campaign> campaigns) {
        Set<String> channels = new Set<String>();
        
        for(Campaign c : campaigns) {
            String channel = detectChannelType(c.Name);
            if(channel != 'Other') {
                channels.add(channel);
            }
        }
        
        if(channels.size() >= 3) return 1.0;
        if(channels.size() == 2) return 0.7;
        if(channels.size() == 1) return 0.3;
        
        return 0;
    }
    
    private static Decimal calculateCreatorDiversity(List<Campaign> campaigns) {
        Set<Id> creators = new Set<Id>();
        
        for(Campaign c : campaigns) {
            creators.add(c.CreatedById);
        }
        
        if(creators.size() >= campaigns.size() * 0.7) return 1.0;
        if(creators.size() >= campaigns.size() * 0.5) return 0.7;
        if(creators.size() > 1) return 0.5;
        
        return 0.3;
    }
    
    public static String detectChannelType(String campaignName) {
        String lowerName = campaignName.toLowerCase();
        
        if(lowerName.contains('email') || lowerName.contains('pardot')) {
            return 'Email';
        } else if(lowerName.contains('sms') || lowerName.contains('text') || lowerName.contains('p2p')) {
            return 'SMS';
        } else if(lowerName.contains('call') || lowerName.contains('callhub') || lowerName.contains('phone')) {
            return 'Call';
        } else if(lowerName.contains('facebook') || lowerName.contains('fb') || 
                  lowerName.contains('instagram') || lowerName.contains('social')) {
            return 'Social Media';
        }
        
        return 'Other';
    }
    
    private static Boolean isChannelIndicator(String word) {
        Set<String> channelWords = new Set<String>{
            'email', 'pardot', 'sms', 'text', 'call', 'callhub', 
            'phone', 'facebook', 'fb', 'instagram', 'social', 'p2p'
        };
        return channelWords.contains(word.toLowerCase());
    }
    
    private static void sendSuggestionNotification(Campaign_Grouping_Suggestion__c suggestion, List<Campaign> campaigns) {
        List<String> campaignNames = new List<String>();
        for(Campaign c : campaigns) {
            campaignNames.add(c.Name);
        }
        
        List<User> adminUsers = [
            SELECT Id, Email 
            FROM User 
            WHERE Profile.Name = 'System Administrator' 
            AND IsActive = true
            LIMIT 5
        ];
        
        if(!adminUsers.isEmpty()) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setSubject('New Campaign Grouping Suggestion: ' + suggestion.Suggested_Initiative_Name__c);
            
            String body = '<h3>Campaign Grouping Suggestion</h3>';
            body += '<p>The system has identified the following campaigns that may belong together:</p>';
            body += '<ul>';
            for(String name : campaignNames) {
                body += '<li>' + name + '</li>';
            }
            body += '</ul>';
            body += '<p>Suggested Initiative Name: <strong>' + suggestion.Suggested_Initiative_Name__c + '</strong></p>';
            body += '<p>Confidence Score: <strong>' + (suggestion.Confidence_Score__c * 100).intValue() + '%</strong></p>';
            body += '<p><a href="' + System.URL.getOrgDomainUrl().toExternalForm() + '/' + suggestion.Id + '">Review Suggestion</a></p>';
            
            email.setHtmlBody(body);
            
            List<String> toAddresses = new List<String>();
            for(User u : adminUsers) {
                toAddresses.add(u.Email);
            }
            email.setToAddresses(toAddresses);
            
            try {
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{email});
            } catch(Exception e) {
                System.debug('Failed to send notification email: ' + e.getMessage());
            }
        }
    }
}