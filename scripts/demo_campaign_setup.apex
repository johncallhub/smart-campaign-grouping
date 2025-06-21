// Smart Campaign Grouping Demo Script
// This creates a demo campaign and adds the john jacob contact

System.debug('🚀 Starting Smart Campaign Grouping Demo...');

// 1. Create a demo campaign with a pattern-detectable name
Campaign demoCampaign = new Campaign(
    Name = 'June 2024 Rally - Downtown Event',
    Description = 'Demo campaign created to showcase Smart Campaign Grouping pattern detection',
    Status = 'Planned',
    Type = 'Advertisement',
    StartDate = Date.today(),
    EndDate = Date.today().addDays(30)
);

try {
    insert demoCampaign;
    System.debug('✅ Created demo campaign: ' + demoCampaign.Name);
    System.debug('📋 Campaign ID: ' + demoCampaign.Id);
} catch (Exception e) {
    System.debug('❌ Error creating campaign: ' + e.getMessage());
}

// 2. Find the "john jacob" contact
List<Contact> johnJacobContacts = [
    SELECT Id, Name, Email 
    FROM Contact 
    WHERE (FirstName LIKE '%john%' AND LastName LIKE '%jacob%') 
       OR Name LIKE '%john jacob%'
    LIMIT 5
];

System.debug('🔍 Found ' + johnJacobContacts.size() + ' contacts matching "john jacob":');
for (Contact c : johnJacobContacts) {
    System.debug('   • ' + c.Name + ' (ID: ' + c.Id + ')');
}

// 3. Add the first matching contact to the campaign
if (!johnJacobContacts.isEmpty() && demoCampaign.Id != null) {
    Contact johnJacob = johnJacobContacts[0];
    
    CampaignMember member = new CampaignMember(
        CampaignId = demoCampaign.Id,
        ContactId = johnJacob.Id,
        Status = 'Sent'
    );
    
    try {
        insert member;
        System.debug('✅ Added ' + johnJacob.Name + ' to campaign');
        System.debug('📋 Campaign Member ID: ' + member.Id);
    } catch (Exception e) {
        System.debug('❌ Error adding contact to campaign: ' + e.getMessage());
    }
} else if (johnJacobContacts.isEmpty()) {
    System.debug('⚠️ No contacts found matching "john jacob" - creating one...');
    
    // Create a john jacob contact if none exists
    Contact newContact = new Contact(
        FirstName = 'John',
        LastName = 'Jacob',
        Email = 'john.jacob@demo.com'
    );
    
    try {
        insert newContact;
        System.debug('✅ Created contact: ' + newContact.FirstName + ' ' + newContact.LastName);
        
        // Add to campaign
        if (demoCampaign.Id != null) {
            CampaignMember member = new CampaignMember(
                CampaignId = demoCampaign.Id,
                ContactId = newContact.Id,
                Status = 'Sent'
            );
            insert member;
            System.debug('✅ Added new contact to campaign');
        }
    } catch (Exception e) {
        System.debug('❌ Error creating contact: ' + e.getMessage());
    }
}

// 4. Run the Smart Campaign Grouping Analysis
System.debug('🤖 Now running Smart Campaign Grouping Analysis...');
System.debug('═══════════════════════════════════════════════════');

CampaignIntelligenceSimple.autoGroupCampaigns();

System.debug('═══════════════════════════════════════════════════');
System.debug('🎉 Demo Complete!');
System.debug('📋 Summary:');
System.debug('   • Created campaign: "June 2024 Rally - Downtown Event"');
System.debug('   • Added john jacob contact to campaign');
System.debug('   • Ran Smart Campaign Grouping analysis');
System.debug('   • Check the analysis output above for pattern detection results');