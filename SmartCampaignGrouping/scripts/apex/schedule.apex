// Schedule the monitoring job
System.debug(CampaignGroupingMonitor.scheduleDaily());

// Test the pattern detection
CampaignIntelligence.autoGroupCampaigns();

System.debug('Smart Campaign Grouping deployed successfully!');