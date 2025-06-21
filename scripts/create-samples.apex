// Create sample campaigns to demonstrate pattern detection
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

insert samples;
System.debug('✅ Created ' + samples.size() + ' sample campaigns!');

// Now run the pattern detection
CampaignIntelligenceSimple.autoGroupCampaigns();