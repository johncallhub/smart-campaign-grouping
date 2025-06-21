public class CampaignIntelligence {
    
    // Runs every hour to find ungrouped campaigns
    @InvocableMethod(label='Auto-Group Campaigns')
    public static void autoGroupCampaigns() {
        
        // Step 1: Find campaigns created in last 7 days without grouping
        List<Campaign> recentCampaigns = [
            SELECT Id, Name, CreatedDate, Type, Description, 
                   Campaign_Initiative__c, ParentId
            FROM Campaign
            WHERE CreatedDate = LAST_N_DAYS:7
            AND Campaign_Initiative__c = null
            ORDER BY CreatedDate DESC
        ];
        
        System.debug('=== Campaign Intelligence Auto-Grouping ===');
        System.debug('Found ' + recentCampaigns.size() + ' recent ungrouped campaigns');
        
        // Step 2: Extract patterns from campaign names
        Map<String, List<Campaign>> potentialGroups = new Map<String, List<Campaign>>();
        
        for(Campaign c : recentCampaigns) {
            // Smart pattern extraction
            String pattern = extractKeyPattern(c.Name);
            System.debug('Campaign: ' + c.Name + ' -> Pattern: ' + pattern);
            
            if(!potentialGroups.containsKey(pattern)) {
                potentialGroups.put(pattern, new List<Campaign>());
            }
            potentialGroups.get(pattern).add(c);
        }
        
        // Step 3: Create grouping suggestions
        for(String pattern : potentialGroups.keySet()) {
            List<Campaign> relatedCampaigns = potentialGroups.get(pattern);
            
            if(relatedCampaigns.size() >= 2) {
                System.debug('Creating suggestion for pattern: ' + pattern + ' with ' + relatedCampaigns.size() + ' campaigns');
                GroupingSuggestionEngine.createGroupingSuggestion(pattern, relatedCampaigns);
            }
        }
        
        System.debug('=== Auto-Grouping Complete ===');
    }
    
    // Intelligent pattern extraction
    private static String extractKeyPattern(String campaignName) {
        if (String.isBlank(campaignName)) {
            return 'Unknown';
        }
        
        // Remove common prefixes
        String cleaned = campaignName
            .replaceAll('(?i)(CallHub|CH|Pardot|Email|SMS|Text|Call|Facebook|FB)', '')
            .replaceAll('(?i)(Campaign|Outreach)', '')
            .trim();
        
        // Extract key terms (month + event type)
        Pattern eventPattern = Pattern.compile('(?i)(\\w+)\\s*(Rally|GOTV|Fundrais|Voter|Registration|Drive|Event)');
        Matcher m = eventPattern.matcher(cleaned);
        
        if(m.find()) {
            return m.group(1) + ' ' + m.group(2);
        }
        
        // Fallback: extract date + first meaningful word
        return extractDateAndKeyword(cleaned);
    }
    
    // Extract date and keyword patterns
    private static String extractDateAndKeyword(String cleaned) {
        // Look for month names
        Pattern monthPattern = Pattern.compile('(?i)(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)');
        Matcher monthMatcher = monthPattern.matcher(cleaned);
        
        String month = '';
        if (monthMatcher.find()) {
            month = monthMatcher.group(1);
        }
        
        // Look for meaningful keywords
        Pattern keywordPattern = Pattern.compile('(?i)(\\b(?:Rally|Event|Fundraiser|Voter|Registration|Drive|GOTV|Outreach|Survey|Poll|Town|Hall|Meeting|Conference|Workshop)\\b)');
        Matcher keywordMatcher = keywordPattern.matcher(cleaned);
        
        String keyword = '';
        if (keywordMatcher.find()) {
            keyword = keywordMatcher.group(1);
        }
        
        // Combine month and keyword
        if (!String.isBlank(month) && !String.isBlank(keyword)) {
            return month + ' ' + keyword;
        } else if (!String.isBlank(month)) {
            return month + ' Campaign';
        } else if (!String.isBlank(keyword)) {
            return keyword;  
        }
        
        // Final fallback - use first 2 meaningful words
        List<String> words = cleaned.split('\\s+');
        List<String> meaningfulWords = new List<String>();
        
        for (String word : words) {
            if (word.length() > 2 && !isStopWord(word)) {
                meaningfulWords.add(word);
                if (meaningfulWords.size() >= 2) {
                    break;
                }
            }
        }
        
        if (meaningfulWords.size() > 0) {
            return String.join(meaningfulWords, ' ');
        }
        
        return 'General Campaign';
    }
    
    // Check if word is a stop word
    private static Boolean isStopWord(String word) {
        Set<String> stopWords = new Set<String>{
            'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by',
            '2024', '2023', '2025', 'test', 'new', 'old', 'big', 'small'
        };
        return stopWords.contains(word.toLowerCase());
    }
    
    // Advanced pattern matching for related campaigns
    public static List<Campaign> findRelatedCampaigns(String campaignName, Integer dayRange) {
        String pattern = extractKeyPattern(campaignName);
        
        List<Campaign> potentialMatches = [
            SELECT Id, Name, CreatedDate, Type, Description
            FROM Campaign
            WHERE CreatedDate = LAST_N_DAYS:7
            AND Campaign_Initiative__c = null
            ORDER BY CreatedDate DESC
        ];
        
        List<Campaign> relatedCampaigns = new List<Campaign>();
        
        for (Campaign c : potentialMatches) {
            if (extractKeyPattern(c.Name) == pattern) {
                relatedCampaigns.add(c);
            }
        }
        
        return relatedCampaigns;
    }
    
    // Method for manual pattern analysis
    @AuraEnabled
    public static String analyzePattern(String campaignName) {
        return extractKeyPattern(campaignName);
    }
}