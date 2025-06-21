import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import autoGroupCampaigns from '@salesforce/apex/CampaignIntelligenceSimple.autoGroupCampaignsWithReturn';

export default class SmartGroupingButton extends LightningElement {
    isLoading = false;

    async handleAnalyzeCampaigns() {
        this.isLoading = true;
        
        try {
            await autoGroupCampaigns();
            
            this.dispatchEvent(new ShowToastEvent({
                title: 'Smart Campaign Grouping',
                message: 'Analysis complete! Check the browser console (F12) for detailed grouping suggestions.',
                variant: 'success',
                mode: 'sticky'
            }));
            
            console.log('🤖 Smart Campaign Grouping Analysis Complete!');
            console.log('📋 Check your Salesforce debug logs for detailed suggestions');
            console.log('🔍 Or run this in Developer Console: CampaignIntelligenceSimple.autoGroupCampaigns();');
            
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Error analyzing campaigns: ' + error.body?.message || error.message,
                variant: 'error'
            }));
            console.error('Error:', error);
        } finally {
            this.isLoading = false;
        }
    }
}