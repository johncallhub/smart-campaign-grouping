public class CampaignIntelligenceSimple {
    @InvocableMethod(label='Auto-Group Campaigns Simple' description='Detect campaign grouping patterns and output to debug logs')
    public static void autoGroupCampaigns() {
        autoGroupCampaignsWithReturn();
    }
    
    @AuraEnabled
    public static String autoGroupCampaignsWithReturn() {
        System.debug('=== Smart Campaign Grouping Analysis ===');
        
        // Find recent campaigns
        List<Campaign> campaigns = [
            SELECT Id, Name, CreatedDate, Type, Description
            FROM Campaign
            WHERE CreatedDate = LAST_N_DAYS:30
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];
        
        System.debug('Found ' + campaigns.size() + ' campaigns in last 30 days');
        
        if(campaigns.isEmpty()) {
            System.debug('No recent campaigns found. Creating sample data...');
            createSampleCampaigns();
            return 'No campaigns found, created sample data';
        }
        
        // Pattern detection
        Map<String, List<Campaign>> patterns = new Map<String, List<Campaign>>();
        
        for(Campaign c : campaigns) {
            String pattern = extractPattern(c.Name);
            if(String.isNotBlank(pattern)) {
                if(!patterns.containsKey(pattern)) {
                    patterns.put(pattern, new List<Campaign>());
                }
                patterns.get(pattern).add(c);
            }
        }
        
        // Report findings
        System.debug('=== GROUPING SUGGESTIONS ===');
        for(String pattern : patterns.keySet()) {
            List<Campaign> relatedCampaigns = patterns.get(pattern);
            if(relatedCampaigns.size() >= 2) {
                Decimal confidence = calculateConfidence(relatedCampaigns);
                System.debug('✨ SUGGESTION: "' + pattern + '" (' + confidence.intValue() + '% confidence)');
                for(Campaign c : relatedCampaigns) {
                    System.debug('  - ' + c.Name + ' (Created: ' + c.CreatedDate.format() + ')');
                }
                System.debug('');
            }
        }
        
        System.debug('=== Analysis Complete ===');
        return 'Analysis complete! Check debug logs for detailed suggestions.';
    }
    
    private static String extractPattern(String campaignName) {
        if(String.isBlank(campaignName)) return null;
        
        String name = campaignName.toLowerCase();
        
        // Remove common prefixes
        name = name.replaceAll('(?i)(callhub|ch|pardot|email|sms|text|call|facebook|fb)', '');
        name = name.replaceAll('(?i)(campaign|outreach)', '');
        name = name.trim();
        
        // Look for month + event type patterns
        Pattern monthEvent = Pattern.compile('(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\s*(rally|gotv|fundrais|voter|registration|drive|event|town\\s*hall)');
        Matcher m = monthEvent.matcher(name);
        if(m.find()) {
            return m.group(1).substring(0,1).toUpperCase() + m.group(1).substring(1) + ' ' + 
                   m.group(2).substring(0,1).toUpperCase() + m.group(2).substring(1);
        }
        
        // Look for other common patterns
        if(name.contains('rally')) return 'Rally Campaign';
        if(name.contains('gotv') || name.contains('get out')) return 'GOTV Campaign';
        if(name.contains('fundrais')) return 'Fundraising Campaign';
        if(name.contains('voter reg')) return 'Voter Registration';
        
        return null;
    }
    
    private static Decimal calculateConfidence(List<Campaign> campaigns) {
        Decimal score = 50; // Base score
        
        // Same week bonus
        if(campaigns.size() >= 2) {
            Date firstDate = campaigns[0].CreatedDate.date();
            Date lastDate = campaigns[campaigns.size()-1].CreatedDate.date();
            Integer daysBetween = firstDate.daysBetween(lastDate);
            if(daysBetween <= 7) score += 30;
            if(daysBetween <= 3) score += 20;
        }
        
        // Multiple campaigns bonus
        if(campaigns.size() >= 3) score += 20;
        if(campaigns.size() >= 4) score += 10;
        
        return Math.min(score, 100);
    }
    
    private static void createSampleCampaigns() {
        System.debug('Creating sample campaigns for demonstration...');
        
        List<Campaign> samples = new List<Campaign>{
            new Campaign(Name = 'CallHub June Rally 2024', Type = 'Other', IsActive = true),
            new Campaign(Name = 'Pardot Email June Rally Supporters', Type = 'Email', IsActive = true),
            new Campaign(Name = 'SMS June Rally Reminder', Type = 'Other', IsActive = true),
            new Campaign(Name = 'Facebook June Rally Event', Type = 'Other', IsActive = true),
            new Campaign(Name = 'Voter Registration Drive July', Type = 'Other', IsActive = true),
            new Campaign(Name = 'CallHub Voter Reg Calls', Type = 'Other', IsActive = true),
            new Campaign(Name = 'GOTV November Push', Type = 'Other', IsActive = true),
            new Campaign(Name = 'Email GOTV Final Reminder', Type = 'Email', IsActive = true)
        };
        
        try {
            insert samples;
            System.debug('Sample campaigns created! Re-run the analysis to see grouping suggestions.');
        } catch(Exception e) {
            System.debug('Could not create sample campaigns: ' + e.getMessage());
        }
    }
}