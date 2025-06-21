public class CampaignGroupingLearner {
    
    // Learn from user actions to improve future suggestions
    @future
    public static void learnFromUserAction(Id suggestionId, String action) {
        try {
            Campaign_Grouping_Suggestion__c suggestion = [
                SELECT Id, Suggested_Initiative_Name__c, Confidence_Score__c,
                       (SELECT Campaign__r.Name, Campaign__r.Type, Campaign__r.CreatedDate, 
                               Original_Name__c, Channel_Type__c
                        FROM Campaign_Suggestion_Members__r)
                FROM Campaign_Grouping_Suggestion__c
                WHERE Id = :suggestionId
                LIMIT 1
            ];
            
            if(action == 'APPROVED') {
                // Store successful pattern
                ML_Pattern__c pattern = new ML_Pattern__c(
                    Pattern_Type__c = 'Campaign_Grouping',
                    Success_Rate__c = 1.0,
                    Pattern_Data__c = JSON.serialize(extractPatternFeatures(suggestion)),
                    Usage_Count__c = 1,
                    Last_Used__c = DateTime.now()
                );
                insert pattern;
                
                // Update existing similar patterns
                updateSimilarPatterns(suggestion, true);
                
            } else if(action == 'REJECTED') {
                // Learn what doesn't work
                updateNegativePatterns(suggestion);
                
            } else if(action == 'MODIFIED') {
                // Learn from user corrections
                captureUserCorrections(suggestion);
            }
            
        } catch(Exception e) {
            System.debug('Error in learning from user action: ' + e.getMessage());
        }
    }
    
    // Extract pattern features for machine learning
    private static Map<String, Object> extractPatternFeatures(Campaign_Grouping_Suggestion__c suggestion) {
        Map<String, Object> features = new Map<String, Object>();
        
        // Basic suggestion info
        features.put('suggested_name', suggestion.Suggested_Initiative_Name__c);
        features.put('confidence_score', suggestion.Confidence_Score__c);
        features.put('campaign_count', suggestion.Campaign_Suggestion_Members__r.size());
        
        // Channel analysis
        Map<String, Integer> channelCounts = new Map<String, Integer>();
        Set<String> uniqueKeywords = new Set<String>();
        List<String> campaignNames = new List<String>();
        
        for(Campaign_Suggestion_Member__c member : suggestion.Campaign_Suggestion_Members__r) {
            // Channel distribution
            String channel = member.Channel_Type__c != null ? member.Channel_Type__c : 'Other';
            Integer count = channelCounts.containsKey(channel) ? channelCounts.get(channel) : 0;
            channelCounts.put(channel, count + 1);
            
            // Extract keywords
            campaignNames.add(member.Original_Name__c);
            List<String> words = member.Original_Name__c.toLowerCase().split('\\s+');
            for(String word : words) {
                if(word.length() > 3 && !isStopWord(word)) {
                    uniqueKeywords.add(word);
                }
            }
        }
        
        features.put('channel_distribution', channelCounts);
        features.put('unique_keywords', new List<String>(uniqueKeywords));
        features.put('campaign_names', campaignNames);
        
        // Temporal patterns
        DateTime minDate = null;
        DateTime maxDate = null;
        for(Campaign_Suggestion_Member__c member : suggestion.Campaign_Suggestion_Members__r) {
            DateTime createdDate = member.Campaign__r.CreatedDate;
            if(minDate == null || createdDate < minDate) minDate = createdDate;
            if(maxDate == null || createdDate > maxDate) maxDate = createdDate;
        }
        
        if(minDate != null && maxDate != null) {
            Long timeSpanHours = (maxDate.getTime() - minDate.getTime()) / (1000 * 60 * 60);
            features.put('time_span_hours', timeSpanHours);
        }
        
        return features;
    }
    
    // Update similar patterns based on user feedback
    private static void updateSimilarPatterns(Campaign_Grouping_Suggestion__c suggestion, Boolean positive) {
        List<ML_Pattern__c> existingPatterns = [
            SELECT Id, Pattern_Data__c, Success_Rate__c, Usage_Count__c
            FROM ML_Pattern__c
            WHERE Pattern_Type__c = 'Campaign_Grouping'
            AND Last_Used__c = LAST_N_DAYS:30
        ];
        
        Map<String, Object> currentFeatures = extractPatternFeatures(suggestion);
        List<ML_Pattern__c> patternsToUpdate = new List<ML_Pattern__c>();
        
        for(ML_Pattern__c pattern : existingPatterns) {
            try {
                Map<String, Object> patternFeatures = (Map<String, Object>)JSON.deserializeUntyped(pattern.Pattern_Data__c);
                Decimal similarity = calculatePatternSimilarity(currentFeatures, patternFeatures);
                
                if(similarity > 0.7) {
                    // Update success rate using weighted average
                    Decimal currentSuccessRate = pattern.Success_Rate__c;
                    Decimal usageCount = pattern.Usage_Count__c != null ? pattern.Usage_Count__c : 1;
                    Decimal newValue = positive ? 1.0 : 0.0;
                    
                    Decimal newSuccessRate = ((currentSuccessRate * usageCount) + newValue) / (usageCount + 1);
                    
                    pattern.Success_Rate__c = newSuccessRate;
                    pattern.Usage_Count__c = usageCount + 1;
                    pattern.Last_Used__c = DateTime.now();
                    patternsToUpdate.add(pattern);
                }
            } catch(Exception e) {
                System.debug('Error processing pattern: ' + e.getMessage());
            }
        }
        
        if(!patternsToUpdate.isEmpty()) {
            update patternsToUpdate;
        }
    }
    
    // Calculate similarity between two pattern feature sets
    private static Decimal calculatePatternSimilarity(Map<String, Object> features1, Map<String, Object> features2) {
        Decimal similarity = 0;
        Integer totalComparisons = 0;
        
        // Compare channel distribution
        if(features1.containsKey('channel_distribution') && features2.containsKey('channel_distribution')) {
            Map<String, Object> channels1 = (Map<String, Object>)features1.get('channel_distribution');
            Map<String, Object> channels2 = (Map<String, Object>)features2.get('channel_distribution');
            similarity += compareChannelDistribution(channels1, channels2) * 0.4;
            totalComparisons++;
        }
        
        // Compare keywords
        if(features1.containsKey('unique_keywords') && features2.containsKey('unique_keywords')) {
            List<Object> keywords1 = (List<Object>)features1.get('unique_keywords');
            List<Object> keywords2 = (List<Object>)features2.get('unique_keywords');
            similarity += compareKeywords(keywords1, keywords2) * 0.4;
            totalComparisons++;
        }
        
        // Compare time spans
        if(features1.containsKey('time_span_hours') && features2.containsKey('time_span_hours')) {
            Decimal timeSpan1 = (Decimal)features1.get('time_span_hours');
            Decimal timeSpan2 = (Decimal)features2.get('time_span_hours');
            similarity += compareTimeSpans(timeSpan1, timeSpan2) * 0.2;
            totalComparisons++;
        }
        
        return totalComparisons > 0 ? similarity / totalComparisons : 0;
    }
    
    private static Decimal compareChannelDistribution(Map<String, Object> channels1, Map<String, Object> channels2) {
        Set<String> allChannels = new Set<String>();
        allChannels.addAll(channels1.keySet());
        allChannels.addAll(channels2.keySet());
        
        Decimal totalDifference = 0;
        for(String channel : allChannels) {
            Integer count1 = channels1.containsKey(channel) ? (Integer)channels1.get(channel) : 0;
            Integer count2 = channels2.containsKey(channel) ? (Integer)channels2.get(channel) : 0;
            totalDifference += Math.abs(count1 - count2);
        }
        
        return Math.max(0, 1 - (totalDifference / 10.0)); // Normalize
    }
    
    private static Decimal compareKeywords(List<Object> keywords1, List<Object> keywords2) {
        Set<String> set1 = new Set<String>();
        Set<String> set2 = new Set<String>();
        
        for(Object kw : keywords1) set1.add((String)kw);
        for(Object kw : keywords2) set2.add((String)kw);
        
        Set<String> intersection = set1.clone();
        intersection.retainAll(set2);
        
        Set<String> union = set1.clone();
        union.addAll(set2);
        
        return union.size() > 0 ? (Decimal)intersection.size() / union.size() : 0;
    }
    
    private static Decimal compareTimeSpans(Decimal timeSpan1, Decimal timeSpan2) {
        Decimal maxTimeSpan = Math.max(timeSpan1, timeSpan2);
        Decimal difference = Math.abs(timeSpan1 - timeSpan2);
        return maxTimeSpan > 0 ? Math.max(0, 1 - (difference / maxTimeSpan)) : 1;
    }
    
    private static void updateNegativePatterns(Campaign_Grouping_Suggestion__c suggestion) {
        // Create negative pattern to avoid similar suggestions in the future
        ML_Pattern__c negativePattern = new ML_Pattern__c(
            Pattern_Type__c = 'Campaign_Grouping',
            Success_Rate__c = 0.0,
            Pattern_Data__c = JSON.serialize(extractPatternFeatures(suggestion)),
            Usage_Count__c = 1,
            Last_Used__c = DateTime.now()
        );
        insert negativePattern;
        
        // Update similar patterns negatively
        updateSimilarPatterns(suggestion, false);
    }
    
    private static void captureUserCorrections(Campaign_Grouping_Suggestion__c suggestion) {
        // If user modified the suggestion, learn from their corrections
        Map<String, Object> features = extractPatternFeatures(suggestion);
        features.put('user_corrected', true);
        features.put('correction_type', 'modified_name');
        
        ML_Pattern__c correctionPattern = new ML_Pattern__c(
            Pattern_Type__c = 'Campaign_Grouping',
            Success_Rate__c = 0.8, // Partial success since user had to modify
            Pattern_Data__c = JSON.serialize(features),
            Usage_Count__c = 1,
            Last_Used__c = DateTime.now()
        );
        insert correctionPattern;
    }
    
    // Check if word is a stop word (helper method)
    private static Boolean isStopWord(String word) {
        Set<String> stopWords = new Set<String>{
            'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by',
            '2024', '2023', '2025', 'test', 'new', 'old', 'big', 'small', 'campaign',
            'email', 'sms', 'call', 'text', 'facebook', 'instagram'
        };
        return stopWords.contains(word.toLowerCase());
    }
    
    // Get learned patterns for confidence scoring adjustment
    public static Map<String, Decimal> getLearnedPatternWeights() {
        Map<String, Decimal> weights = new Map<String, Decimal>();
        
        List<ML_Pattern__c> successfulPatterns = [
            SELECT Pattern_Data__c, Success_Rate__c, Usage_Count__c
            FROM ML_Pattern__c
            WHERE Pattern_Type__c = 'Campaign_Grouping'
            AND Success_Rate__c > 0.7
            AND Usage_Count__c > 2
            ORDER BY Success_Rate__c DESC, Usage_Count__c DESC
            LIMIT 50
        ];
        
        for(ML_Pattern__c pattern : successfulPatterns) {
            try {
                Map<String, Object> features = (Map<String, Object>)JSON.deserializeUntyped(pattern.Pattern_Data__c);
                String suggestedName = (String)features.get('suggested_name');
                if(!String.isBlank(suggestedName)) {
                    weights.put(suggestedName, pattern.Success_Rate__c);
                }
            } catch(Exception e) {
                System.debug('Error processing learned pattern: ' + e.getMessage());
            }
        }
        
        return weights;
    }
}