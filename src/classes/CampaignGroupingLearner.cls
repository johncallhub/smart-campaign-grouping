public class CampaignGroupingLearner {
    
    @future
    public static void learnFromUserAction(Id suggestionId, String action) {
        try {
            Campaign_Grouping_Suggestion__c suggestion = [
                SELECT Id, Suggested_Initiative_Name__c, Confidence_Score__c,
                       (SELECT Id, Campaign__r.Name, Campaign__r.Type, Original_Name__c 
                        FROM Campaign_Suggestion_Members__r)
                FROM Campaign_Grouping_Suggestion__c
                WHERE Id = :suggestionId
                LIMIT 1
            ];
            
            if(action == 'APPROVED') {
                storeSuccessfulPattern(suggestion);
            } else if(action == 'REJECTED') {
                updateNegativePatterns(suggestion);
            } else if(action == 'MODIFIED') {
                captureUserCorrections(suggestion);
            }
            
        } catch(Exception e) {
            System.debug('Error in learning process: ' + e.getMessage());
        }
    }
    
    private static void storeSuccessfulPattern(Campaign_Grouping_Suggestion__c suggestion) {
        PatternData pattern = extractPatternFeatures(suggestion);
        
        ML_Pattern__c mlPattern = new ML_Pattern__c(
            Pattern_Type__c = 'Campaign_Grouping_Success',
            Pattern_Name__c = suggestion.Suggested_Initiative_Name__c,
            Success_Rate__c = 1.0,
            Confidence_Threshold__c = suggestion.Confidence_Score__c,
            Pattern_Data__c = JSON.serialize(pattern),
            Usage_Count__c = 1,
            Last_Used__c = DateTime.now()
        );
        
        try {
            insert mlPattern;
            updateGlobalSuccessMetrics();
        } catch(Exception e) {
            System.debug('Failed to store successful pattern: ' + e.getMessage());
        }
    }
    
    private static void updateNegativePatterns(Campaign_Grouping_Suggestion__c suggestion) {
        PatternData pattern = extractPatternFeatures(suggestion);
        
        ML_Pattern__c mlPattern = new ML_Pattern__c(
            Pattern_Type__c = 'Campaign_Grouping_Failure',
            Pattern_Name__c = suggestion.Suggested_Initiative_Name__c + '_REJECTED',
            Success_Rate__c = 0.0,
            Confidence_Threshold__c = suggestion.Confidence_Score__c,
            Pattern_Data__c = JSON.serialize(pattern),
            Usage_Count__c = 1,
            Last_Used__c = DateTime.now()
        );
        
        try {
            insert mlPattern;
        } catch(Exception e) {
            System.debug('Failed to store negative pattern: ' + e.getMessage());
        }
    }
    
    private static void captureUserCorrections(Campaign_Grouping_Suggestion__c suggestion) {
        // This would be enhanced to capture what the user changed
        // For now, we'll treat it as partial success
        PatternData pattern = extractPatternFeatures(suggestion);
        
        ML_Pattern__c mlPattern = new ML_Pattern__c(
            Pattern_Type__c = 'Campaign_Grouping_Modified',
            Pattern_Name__c = suggestion.Suggested_Initiative_Name__c + '_MODIFIED',
            Success_Rate__c = 0.7, // Partial success
            Confidence_Threshold__c = suggestion.Confidence_Score__c,
            Pattern_Data__c = JSON.serialize(pattern),
            Usage_Count__c = 1,
            Last_Used__c = DateTime.now()
        );
        
        try {
            insert mlPattern;
        } catch(Exception e) {
            System.debug('Failed to store modification pattern: ' + e.getMessage());
        }
    }
    
    private static PatternData extractPatternFeatures(Campaign_Grouping_Suggestion__c suggestion) {
        PatternData data = new PatternData();
        data.initiativeName = suggestion.Suggested_Initiative_Name__c;
        data.campaignCount = suggestion.Campaign_Suggestion_Members__r.size();
        data.confidenceScore = suggestion.Confidence_Score__c;
        
        Set<String> channelTypes = new Set<String>();
        Set<String> keywords = new Set<String>();
        
        for(Campaign_Suggestion_Member__c member : suggestion.Campaign_Suggestion_Members__r) {
            String channelType = GroupingSuggestionEngine.detectChannelType(member.Campaign__r.Name);
            channelTypes.add(channelType);
            
            // Extract keywords from campaign names
            List<String> words = member.Campaign__r.Name.toLowerCase().split('\\s+');
            for(String word : words) {
                if(word.length() > 3 && !isStopWord(word)) {
                    keywords.add(word);
                }
            }
        }
        
        data.channelTypes = new List<String>(channelTypes);
        data.commonKeywords = new List<String>(keywords);
        data.channelDiversity = channelTypes.size();
        
        return data;
    }
    
    private static Boolean isStopWord(String word) {
        Set<String> stopWords = new Set<String>{
            'the', 'and', 'for', 'with', 'from', 'about', 'into', 'through',
            'campaign', 'email', 'sms', 'call', 'text', 'facebook', 'pardot'
        };
        return stopWords.contains(word.toLowerCase());
    }
    
    private static void updateGlobalSuccessMetrics() {
        // Update system-wide learning metrics
        Grouping_Analytics__c analytics = Grouping_Analytics__c.getOrgDefaults();
        if(analytics == null) {
            analytics = new Grouping_Analytics__c(
                Total_Suggestions__c = 0,
                Approved_Suggestions__c = 0,
                Success_Rate__c = 0
            );
        }
        
        analytics.Total_Suggestions__c = (analytics.Total_Suggestions__c != null ? analytics.Total_Suggestions__c : 0) + 1;
        analytics.Approved_Suggestions__c = (analytics.Approved_Suggestions__c != null ? analytics.Approved_Suggestions__c : 0) + 1;
        analytics.Success_Rate__c = (analytics.Approved_Suggestions__c / analytics.Total_Suggestions__c) * 100;
        
        upsert analytics;
    }
    
    public static Decimal getSuccessRate() {
        Grouping_Analytics__c analytics = Grouping_Analytics__c.getOrgDefaults();
        return analytics != null ? analytics.Success_Rate__c : 0;
    }
    
    public static List<String> getTopSuccessfulPatterns(Integer limitSize) {
        List<ML_Pattern__c> patterns = [
            SELECT Pattern_Name__c, Success_Rate__c, Usage_Count__c
            FROM ML_Pattern__c
            WHERE Pattern_Type__c = 'Campaign_Grouping_Success'
            AND Success_Rate__c > 0.8
            ORDER BY Usage_Count__c DESC, Success_Rate__c DESC
            LIMIT :limitSize
        ];
        
        List<String> patternNames = new List<String>();
        for(ML_Pattern__c pattern : patterns) {
            patternNames.add(pattern.Pattern_Name__c);
        }
        
        return patternNames;
    }
    
    private class PatternData {
        public String initiativeName { get; set; }
        public Integer campaignCount { get; set; }
        public Decimal confidenceScore { get; set; }
        public List<String> channelTypes { get; set; }
        public List<String> commonKeywords { get; set; }
        public Integer channelDiversity { get; set; }
        
        public PatternData() {
            this.channelTypes = new List<String>();
            this.commonKeywords = new List<String>();
        }
    }
}