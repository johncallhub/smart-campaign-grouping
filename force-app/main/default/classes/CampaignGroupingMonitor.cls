public class CampaignGroupingMonitor implements Schedulable {
    
    public void execute(SchedulableContext sc) {
        
        monitorUngroupedCampaigns();
        
        autoGroupObviousMatches();
        
        CampaignIntelligence.autoGroupCampaigns();
        
        cleanupOldSuggestions();
    }
    
    private void monitorUngroupedCampaigns() {
        Integer ungroupedCount = [
            SELECT COUNT() 
            FROM Campaign 
            WHERE Campaign_Initiative__c = null 
            AND ParentId = null
            AND CreatedDate = LAST_N_DAYS:30
        ];
        
        if(ungroupedCount > 10) {
            sendUngroupedAlert(ungroupedCount);
        }
        
        generateDailyReport();
    }
    
    private void sendUngroupedAlert(Integer ungroupedCount) {
        List<User> adminUsers = [
            SELECT Id, Email 
            FROM User 
            WHERE Profile.Name IN ('System Administrator', 'Marketing User')
            AND IsActive = true
            LIMIT 10
        ];
        
        if(!adminUsers.isEmpty()) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setSubject('Campaign Grouping Alert: ' + ungroupedCount + ' ungrouped campaigns');
            
            String body = '<h3>Campaign Grouping Status Alert</h3>';
            body += '<p>There are currently <strong>' + ungroupedCount + '</strong> ungrouped campaigns from the last 30 days.</p>';
            body += '<p>Consider reviewing the <a href="' + generateDashboardUrl() + '">Campaign Grouping Dashboard</a> to approve pending suggestions.</p>';
            body += '<h4>Recent Ungrouped Campaigns:</h4>';
            body += generateRecentCampaignsList();
            
            email.setHtmlBody(body);
            
            List<String> toAddresses = new List<String>();
            for(User u : adminUsers) {
                if(String.isNotBlank(u.Email)) {
                    toAddresses.add(u.Email);
                }
            }
            
            if(!toAddresses.isEmpty()) {
                email.setToAddresses(toAddresses);
                
                try {
                    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{email});
                } catch(Exception e) {
                    System.debug('Failed to send ungrouped alert: ' + e.getMessage());
                }
            }
        }
    }
    
    private String generateRecentCampaignsList() {
        List<Campaign> recentCampaigns = [
            SELECT Name, CreatedDate, CreatedBy.Name
            FROM Campaign
            WHERE Campaign_Initiative__c = null 
            AND ParentId = null
            AND CreatedDate = LAST_N_DAYS:7
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
        
        String html = '<ul>';
        for(Campaign c : recentCampaigns) {
            html += '<li>' + c.Name + ' (Created: ' + c.CreatedDate.format() + ' by ' + c.CreatedBy.Name + ')</li>';
        }
        html += '</ul>';
        
        return html;
    }
    
    private void autoGroupObviousMatches() {
        List<Campaign_Grouping_Suggestion__c> highConfidence = [
            SELECT Id, Suggested_Initiative_Name__c,
                   (SELECT Campaign__c FROM Campaign_Suggestion_Members__r)
            FROM Campaign_Grouping_Suggestion__c 
            WHERE Confidence_Score__c >= 0.95 
            AND Status__c = 'Pending Review'
            AND CreatedDate < :DateTime.now().addHours(-24)
            LIMIT 5
        ];
        
        for(Campaign_Grouping_Suggestion__c suggestion : highConfidence) {
            try {
                autoApproveSuggestion(suggestion);
            } catch(Exception e) {
                System.debug('Failed to auto-approve suggestion ' + suggestion.Id + ': ' + e.getMessage());
                continue;
            }
        }
    }
    
    private void autoApproveSuggestion(Campaign_Grouping_Suggestion__c suggestion) {
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
        suggestion.Approved_By__c = null; // System approved
        suggestion.Approval_Date__c = DateTime.now();
        update suggestion;
        
        System.debug('Auto-approved suggestion: ' + suggestion.Suggested_Initiative_Name__c);
    }
    
    private void generateDailyReport() {
        DailyReportData reportData = new DailyReportData();
        
        reportData.totalCampaigns = [SELECT COUNT() FROM Campaign WHERE CreatedDate = TODAY];
        reportData.groupedToday = [SELECT COUNT() FROM Campaign WHERE CreatedDate = TODAY AND ParentId != null];
        reportData.pendingSuggestions = [SELECT COUNT() FROM Campaign_Grouping_Suggestion__c WHERE Status__c = 'Pending Review'];
        reportData.autoApprovedToday = [SELECT COUNT() FROM Campaign_Grouping_Suggestion__c WHERE Status__c = 'Approved' AND Approval_Date__c = TODAY AND Approved_By__c = null];
        
        System.debug('Daily Report: ' + JSON.serialize(reportData));
    }
    
    private void cleanupOldSuggestions() {
        List<Campaign_Grouping_Suggestion__c> oldRejected = [
            SELECT Id
            FROM Campaign_Grouping_Suggestion__c
            WHERE Status__c = 'Rejected'
            AND CreatedDate < :DateTime.now().addDays(-30)
            LIMIT 100
        ];
        
        if(!oldRejected.isEmpty()) {
            delete oldRejected;
            System.debug('Cleaned up ' + oldRejected.size() + ' old rejected suggestions');
        }
    }
    
    private String generateDashboardUrl() {
        return System.URL.getOrgDomainUrl().toExternalForm() + '/lightning/n/Campaign_Grouping_Dashboard';
    }
    
    public static String scheduleDaily() {
        String cronExpression = '0 0 9 * * ?'; // Daily at 9 AM
        String jobName = 'Campaign Grouping Monitor - Daily';
        
        try {
            System.schedule(jobName, cronExpression, new CampaignGroupingMonitor());
            return 'Scheduled successfully: ' + jobName;
        } catch(Exception e) {
            System.debug('Failed to schedule job: ' + e.getMessage());
            return 'Failed to schedule: ' + e.getMessage();
        }
    }
    
    public static String scheduleHourly() {
        String cronExpression = '0 0 * * * ?'; // Every hour
        String jobName = 'Campaign Grouping Monitor - Hourly';
        
        try {
            System.schedule(jobName, cronExpression, new CampaignGroupingMonitor());
            return 'Scheduled successfully: ' + jobName;
        } catch(Exception e) {
            System.debug('Failed to schedule job: ' + e.getMessage());
            return 'Failed to schedule: ' + e.getMessage();
        }
    }
    
    private class DailyReportData {
        public Integer totalCampaigns { get; set; }
        public Integer groupedToday { get; set; }
        public Integer pendingSuggestions { get; set; }
        public Integer autoApprovedToday { get; set; }
        
        public DailyReportData() {
            this.totalCampaigns = 0;
            this.groupedToday = 0;
            this.pendingSuggestions = 0;
            this.autoApprovedToday = 0;
        }
    }
}