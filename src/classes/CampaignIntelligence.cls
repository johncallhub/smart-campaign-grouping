public class CampaignIntelligence {
    
    @InvocableMethod(label='Auto-Group Campaigns' description='Automatically detects and groups related campaigns')
    public static void autoGroupCampaigns() {
        autoGroupCampaigns(7);
    }
    
    public static void autoGroupCampaigns(Integer daysBack) {
        List<Campaign> recentCampaigns = [
            SELECT Id, Name, CreatedDate, Type, Description, 
                   Campaign_Initiative__c, ParentId, CreatedById
            FROM Campaign
            WHERE CreatedDate = LAST_N_DAYS:7
            AND Campaign_Initiative__c = null
            AND ParentId = null
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
        
        if(recentCampaigns.isEmpty()) {
            return;
        }
        
        Map<String, List<Campaign>> potentialGroups = new Map<String, List<Campaign>>();
        
        for(Campaign c : recentCampaigns) {
            String pattern = extractKeyPattern(c.Name);
            
            if(String.isNotBlank(pattern)) {
                if(!potentialGroups.containsKey(pattern)) {
                    potentialGroups.put(pattern, new List<Campaign>());
                }
                potentialGroups.get(pattern).add(c);
            }
        }
        
        for(String pattern : potentialGroups.keySet()) {
            List<Campaign> relatedCampaigns = potentialGroups.get(pattern);
            
            if(relatedCampaigns.size() >= 2) {
                GroupingSuggestionEngine.createGroupingSuggestion(pattern, relatedCampaigns);
            }
        }
    }
    
    @TestVisible
    private static String extractKeyPattern(String campaignName) {
        if(String.isBlank(campaignName)) {
            return null;
        }
        
        String cleaned = campaignName
            .replaceAll('(?i)(CallHub|CH|Pardot|Email|SMS|Text|Call|Facebook|FB|P2P)', '')
            .replaceAll('(?i)(Campaign|Outreach|Blast)', '')
            .replaceAll('[\\-_]', ' ')
            .replaceAll('\\s+', ' ')
            .trim();
        
        Pattern eventPattern = Pattern.compile('(?i)(\\w+)\\s*(Rally|GOTV|Fundrais|Voter|Registration|Drive|Event|Meeting|Canvass)');
        Matcher m = eventPattern.matcher(cleaned);
        
        if(m.find()) {
            String month = m.group(1);
            String eventType = m.group(2);
            
            month = standardizeMonth(month);
            eventType = standardizeEventType(eventType);
            
            return month + ' ' + eventType;
        }
        
        return extractDateAndKeyword(cleaned);
    }
    
    private static String standardizeMonth(String month) {
        Map<String, String> monthMap = new Map<String, String>{
            'jan' => 'January', 'january' => 'January',
            'feb' => 'February', 'february' => 'February',
            'mar' => 'March', 'march' => 'March',
            'apr' => 'April', 'april' => 'April',
            'may' => 'May',
            'jun' => 'June', 'june' => 'June',
            'jul' => 'July', 'july' => 'July',
            'aug' => 'August', 'august' => 'August',
            'sep' => 'September', 'september' => 'September', 'sept' => 'September',
            'oct' => 'October', 'october' => 'October',
            'nov' => 'November', 'november' => 'November',
            'dec' => 'December', 'december' => 'December'
        };
        
        String lowerMonth = month.toLowerCase();
        return monthMap.containsKey(lowerMonth) ? monthMap.get(lowerMonth) : month;
    }
    
    private static String standardizeEventType(String eventType) {
        Map<String, String> eventMap = new Map<String, String>{
            'fundrais' => 'Fundraiser',
            'voter' => 'Voter Outreach',
            'registration' => 'Registration Drive',
            'drive' => 'Drive',
            'gotv' => 'GOTV',
            'rally' => 'Rally',
            'event' => 'Event',
            'meeting' => 'Meeting',
            'canvass' => 'Canvassing'
        };
        
        String lowerEvent = eventType.toLowerCase();
        for(String key : eventMap.keySet()) {
            if(lowerEvent.contains(key)) {
                return eventMap.get(key);
            }
        }
        
        return eventType;
    }
    
    private static String extractDateAndKeyword(String text) {
        Pattern datePattern = Pattern.compile('(?i)(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec)\\s*(\\d{4})?');
        Matcher dateMatcher = datePattern.matcher(text);
        
        if(dateMatcher.find()) {
            String month = standardizeMonth(dateMatcher.group(1));
            String year = dateMatcher.group(2) != null ? dateMatcher.group(2) : String.valueOf(Date.today().year());
            
            List<String> words = text.split('\\s+');
            for(String word : words) {
                if(word.length() > 3 && 
                   !word.equalsIgnoreCase(month) && 
                   !word.equals(year) &&
                   !isCommonWord(word)) {
                    return month + ' ' + year + ' ' + capitalizeFirst(word);
                }
            }
            
            return month + ' ' + year + ' Campaign';
        }
        
        return null;
    }
    
    private static Boolean isCommonWord(String word) {
        Set<String> commonWords = new Set<String>{
            'the', 'and', 'for', 'with', 'from', 'about', 'into', 'through'
        };
        return commonWords.contains(word.toLowerCase());
    }
    
    private static String capitalizeFirst(String word) {
        if(String.isBlank(word)) {
            return word;
        }
        return word.substring(0, 1).toUpperCase() + word.substring(1).toLowerCase();
    }
}