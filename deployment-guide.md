# Smart Campaign Grouping - Deployment Guide

## Pre-Deployment Checklist

### 1. Environment Preparation
- [ ] Ensure you have System Administrator access
- [ ] Verify Salesforce API access is enabled
- [ ] Confirm org has sufficient storage for custom objects
- [ ] Check that campaigns exist in the org for testing

### 2. Dependencies
- [ ] Salesforce API version 60.0 or higher
- [ ] Lightning Experience enabled
- [ ] Custom Object permissions available
- [ ] Email delivery enabled for notifications

## Step-by-Step Deployment

### Phase 1: Core Components (Week 1)

#### Day 1: Deploy Custom Objects
```bash
# Deploy custom objects first
sfdx force:source:deploy -p src/objects/ -u production-org
```

**Verify Deployment:**
- Navigate to Setup > Object Manager
- Confirm these objects exist:
  - Campaign Grouping Suggestion
  - Campaign Suggestion Member
  - ML Pattern
  - Grouping Analytics

#### Day 2: Add Campaign Custom Field
1. Go to Setup > Object Manager > Campaign
2. Click Fields & Relationships
3. Click New
4. Select Text field type
5. Field Details:
   - Field Label: `Campaign Initiative`
   - Field Name: `Campaign_Initiative__c`
   - Length: 255
   - Help Text: "The initiative this campaign belongs to"
6. Set field-level security for all profiles
7. Add to page layouts as needed

#### Day 3: Deploy Apex Classes
```bash
# Deploy all Apex classes
sfdx force:source:deploy -p src/classes/ -u production-org
```

**Run Tests:**
```bash
# Execute all test classes
sfdx force:apex:test:run -n CampaignIntelligenceTest,GroupingSuggestionEngineTest,GroupingSuggestionControllerTest -u production-org
```

#### Day 4: Deploy Lightning Component
```bash
# Deploy the Lightning Web Component
sfdx force:source:deploy -p src/lwc/ -u production-org
```

#### Day 5: Configure Permissions

**Create Permission Set:**
1. Setup > Permission Sets > New
2. Label: `Campaign Grouping User`
3. API Name: `Campaign_Grouping_User`

**Object Permissions:**
- Campaign Grouping Suggestion: Read, Create, Edit, Delete
- Campaign Suggestion Member: Read, Create, Edit, Delete
- ML Pattern: Read
- Grouping Analytics: Read
- Campaign: Read, Edit (to update Initiative field)

**Apex Class Access:**
- CampaignIntelligence
- GroupingSuggestionEngine
- GroupingSuggestionController
- CampaignGroupingMonitor
- CampaignGroupingLearner

**Assign to Users:**
- Assign permission set to all campaign managers
- Assign to marketing operations team
- Assign to system administrators

### Phase 2: User Interface Setup (Week 2)

#### Day 6: Add Component to Home Page
1. Navigate to Setup > Digital Experiences > All Sites
2. Or go to any Lightning App home page
3. Click Setup (gear icon) > Edit Page
4. Drag `campaignGroupingSuggestions` component to desired section
5. Save and activate

#### Day 7: Create Dedicated Tab (Optional)
1. Setup > Tabs > Lightning Component Tabs
2. Lightning Component: `c:campaignGroupingSuggestions`
3. Tab Label: `Campaign Grouping`
4. Tab Name: `Campaign_Grouping`
5. Add to relevant Lightning Apps

#### Day 8: Configure Email Settings
1. Setup > Deliverability
2. Ensure email deliverability is "All email"
3. Add organization-wide email addresses if needed
4. Test email delivery

### Phase 3: Automation Setup (Week 2)

#### Day 9: Schedule Monitoring Job
Execute in Developer Console (Anonymous Apex):
```javascript
// Schedule daily monitoring at 9 AM
String result = CampaignGroupingMonitor.scheduleDaily();
System.debug(result);

// Verify job was scheduled
List<CronTrigger> jobs = [SELECT Id, CronExpression, NextFireTime 
                         FROM CronTrigger 
                         WHERE CronJobDetail.Name LIKE '%Campaign Grouping%'];
System.debug('Scheduled jobs: ' + jobs.size());
```

#### Day 10: Initial Data Processing
```javascript
// Process existing campaigns for initial suggestions
CampaignIntelligence.autoGroupCampaigns();

// Check results
List<Campaign_Grouping_Suggestion__c> suggestions = [
    SELECT Id, Suggested_Initiative_Name__c, Confidence_Score__c
    FROM Campaign_Grouping_Suggestion__c
];
System.debug('Generated suggestions: ' + suggestions.size());
```

## Post-Deployment Testing

### Week 3: User Acceptance Testing

#### Test Scenario 1: Basic Pattern Detection
1. Create test campaigns:
   - "Email June Rally Invitation"
   - "CallHub June Rally Calls"
   - "SMS June Rally Reminder"
2. Wait 5 minutes or run: `CampaignIntelligence.autoGroupCampaigns();`
3. Verify suggestion appears in component
4. Test approve/reject functionality

#### Test Scenario 2: Confidence Scoring
1. Create campaigns with varying similarity:
   - High similarity: "July Fundraiser Email", "July Fundraiser Calls"
   - Low similarity: "August Newsletter", "September Event"
2. Verify confidence scores reflect similarity
3. Test auto-approval for high-confidence matches

#### Test Scenario 3: Learning Algorithm
1. Approve several suggestions
2. Reject some suggestions
3. Verify system learns from feedback
4. Check `ML_Pattern__c` records for stored patterns

### Week 4: Performance Validation

#### Monitor System Performance
```javascript
// Check system analytics
Grouping_Analytics__c analytics = Grouping_Analytics__c.getOrgDefaults();
System.debug('Success Rate: ' + analytics.Success_Rate__c + '%');

// View learning patterns
List<ML_Pattern__c> patterns = [
    SELECT Pattern_Name__c, Success_Rate__c, Usage_Count__c
    FROM ML_Pattern__c
    ORDER BY Usage_Count__c DESC
];
System.debug('Learning patterns: ' + patterns.size());
```

#### Validate Email Notifications
1. Create campaigns that should trigger suggestions
2. Verify admin users receive email notifications
3. Check email content and formatting
4. Test notification frequency (should not spam)

## Rollback Plan

If issues arise, rollback in reverse order:

### Emergency Rollback
```bash
# 1. Unschedule jobs
# In Developer Console:
List<CronTrigger> jobs = [SELECT Id FROM CronTrigger 
                         WHERE CronJobDetail.Name LIKE '%Campaign Grouping%'];
for(CronTrigger job : jobs) {
    System.abortJob(job.Id);
}

# 2. Remove components from pages
# Manually remove from Lightning pages

# 3. Deactivate permission sets
# Setup > Permission Sets > Deactivate assignments
```

### Full Rollback
```bash
# Delete all components (use with caution)
sfdx force:source:delete -p src/ -u production-org
```

## Production Checklist

### Go-Live Requirements
- [ ] All test classes passing with 75%+ coverage
- [ ] User acceptance testing completed
- [ ] Permission sets assigned to all users
- [ ] Component added to user home pages
- [ ] Monitoring job scheduled and running
- [ ] Email notifications working
- [ ] Initial suggestions generated and tested
- [ ] Documentation provided to users
- [ ] Support process established

### Success Metrics (30-day targets)
- [ ] 95%+ suggestion accuracy
- [ ] 80%+ user adoption
- [ ] <24 hour processing time
- [ ] Zero system errors
- [ ] 100% campaign coverage

## Maintenance & Monitoring

### Weekly Tasks
- Review `Campaign_Grouping_Suggestion__c` records for patterns
- Check `Grouping_Analytics__c` for success rates
- Monitor scheduled job execution
- Review user feedback and suggestions

### Monthly Tasks
- Analyze `ML_Pattern__c` for learning improvements
- Review email notification frequency
- Update pattern matching rules if needed
- Clean up old rejected suggestions

### Quarterly Tasks
- Review and optimize confidence scoring algorithm
- Update channel detection patterns
- Analyze system performance metrics
- Plan enhancements based on usage patterns

## Troubleshooting Common Issues

### Issue: No Suggestions Generated
**Cause:** Campaigns already have Initiative field populated
**Solution:** Clear `Campaign_Initiative__c` field on test campaigns

### Issue: Low Confidence Scores
**Cause:** Campaign naming conventions too varied
**Solution:** Customize pattern matching in `CampaignIntelligence` class

### Issue: Email Notifications Not Sent
**Cause:** Email deliverability settings or user permissions
**Solution:** Check Setup > Deliverability and user email addresses

### Issue: Component Not Loading
**Cause:** Permission or Lightning component issues
**Solution:** Verify permission sets and component deployment

### Issue: Scheduled Job Not Running
**Cause:** Job scheduling permissions or errors
**Solution:** Check scheduled jobs in Setup and debug logs

## Support Contacts

- **Technical Issues:** System Administrator
- **User Training:** Marketing Operations Team
- **Enhancement Requests:** Product Owner
- **Emergency Issues:** IT Support Team

---

**Deployment Timeline: 2-4 weeks**
**User Training: 1 week**
**Full Adoption: 4-6 weeks**

*This deployment guide ensures a smooth rollout of the Smart Campaign Grouping solution with minimal risk and maximum user adoption.*