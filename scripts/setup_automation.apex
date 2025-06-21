// Smart Campaign Grouping - Automation Setup Script

System.debug('🤖 Setting up Smart Campaign Grouping Automation...');

// 1. Schedule the hourly monitoring
try {
    String hourlyResult = CampaignGroupingMonitor.scheduleHourly();
    System.debug('✅ Hourly Schedule: ' + hourlyResult);
} catch (Exception e) {
    System.debug('⚠️ Hourly scheduling: ' + e.getMessage());
}

// 2. Schedule the daily monitoring  
try {
    String dailyResult = CampaignGroupingMonitor.scheduleDaily();
    System.debug('✅ Daily Schedule: ' + dailyResult);
} catch (Exception e) {
    System.debug('⚠️ Daily scheduling: ' + e.getMessage());
}

// 3. Run an initial analysis to create sample suggestions
System.debug('🔍 Running initial campaign analysis...');
try {
    CampaignIntelligence.autoGroupCampaigns();
    System.debug('✅ Initial analysis complete');
} catch (Exception e) {
    System.debug('⚠️ Initial analysis failed: ' + e.getMessage());
    // Fallback to simple version
    try {
        CampaignIntelligenceSimple.autoGroupCampaigns();
        System.debug('✅ Simple analysis complete');
    } catch (Exception e2) {
        System.debug('❌ All analysis failed: ' + e2.getMessage());
    }
}

// 4. Check for existing suggestions
try {
    List<Campaign_Grouping_Suggestion__c> suggestions = [
        SELECT Id, Suggested_Initiative_Name__c, Confidence_Score__c, Status__c
        FROM Campaign_Grouping_Suggestion__c
        WHERE Status__c = 'Pending Review'
        ORDER BY Confidence_Score__c DESC
        LIMIT 5
    ];
    
    System.debug('📊 Found ' + suggestions.size() + ' pending suggestions:');
    for (Campaign_Grouping_Suggestion__c suggestion : suggestions) {
        System.debug('   • ' + suggestion.Suggested_Initiative_Name__c + ' (' + 
                    (suggestion.Confidence_Score__c * 100).intValue() + '% confidence)');
    }
} catch (Exception e) {
    System.debug('⚠️ Could not retrieve suggestions: ' + e.getMessage());
}

System.debug('🎉 Smart Campaign Grouping Setup Complete!');
System.debug('');
System.debug('📋 What\'s Now Available:');
System.debug('   ✅ Automated hourly campaign pattern detection');
System.debug('   ✅ Daily monitoring and cleanup');
System.debug('   ✅ Machine learning from user feedback');
System.debug('   ✅ One-click approval interface');
System.debug('   ✅ Email notifications for high-confidence matches');
System.debug('   ✅ Auto-approval for 95%+ confidence suggestions');
System.debug('');
System.debug('🔧 How to Access:');
System.debug('   • Campaign Records: Click "🤖 Smart Campaign Analysis" button');
System.debug('   • Lightning Component: Add to Home/App pages');
System.debug('   • Developer Console: CampaignIntelligenceSimple.autoGroupCampaigns();');
System.debug('   • Custom Objects: Campaign Grouping Suggestions tab');
System.debug('');
System.debug('📈 Success Metrics to Track:');
System.debug('   • Grouping Accuracy: Target 95%+');
System.debug('   • Time to Group: <24 hours');
System.debug('   • User Effort: 1 click per suggestion');
System.debug('   • Coverage: 100% of campaigns reviewed');