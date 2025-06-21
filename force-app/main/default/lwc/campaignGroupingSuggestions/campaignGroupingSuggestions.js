import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getSuggestions from '@salesforce/apex/GroupingSuggestionController.getSuggestions';
import approveSuggestion from '@salesforce/apex/GroupingSuggestionController.approveSuggestion';
import rejectSuggestion from '@salesforce/apex/GroupingSuggestionController.rejectSuggestion';
import modifySuggestion from '@salesforce/apex/GroupingSuggestionController.modifySuggestion';

export default class CampaignGroupingSuggestions extends LightningElement {
    @track suggestions = [];
    @track isLoading = false;
    @track editingSuggestion = null;
    @track newInitiativeName = '';
    @track selectedCampaigns = new Set();

    wiredSuggestionsResult;

    @wire(getSuggestions)
    wiredSuggestions(result) {
        this.wiredSuggestionsResult = result;
        if (result.data) {
            this.suggestions = result.data.map(suggestion => ({
                ...suggestion,
                campaigns: this.formatCampaignList(suggestion.Campaign_Suggestion_Members__r || []),
                confidencePercent: Math.round(suggestion.Confidence_Score__c * 100),
                confidenceClass: this.getConfidenceClass(suggestion.Confidence_Score__c)
            }));
            this.isLoading = false;
        } else if (result.error) {
            this.showToast('Error', 'Error loading suggestions: ' + result.error.body.message, 'error');
            this.isLoading = false;
        }
    }

    // Visual preview of what will be grouped
    formatCampaignList(members) {
        return members.map(m => ({
            id: m.Id,
            campaignId: m.Campaign__c,
            name: m.Campaign__r ? m.Campaign__r.Name : m.Original_Name__c,
            type: this.detectChannelType(m.Original_Name__c),
            createdDate: m.Campaign__r ? m.Campaign__r.CreatedDate : null,
            originalName: m.Original_Name__c,
            channelType: m.Channel_Type__c || 'Other',
            selected: false
        }));
    }

    detectChannelType(campaignName) {
        const lowerName = campaignName.toLowerCase();
        
        if (lowerName.includes('email') || lowerName.includes('pardot')) {
            return 'Email';
        } else if (lowerName.includes('sms') || lowerName.includes('text') || lowerName.includes('p2p')) {
            return 'SMS';
        } else if (lowerName.includes('call') || lowerName.includes('callhub') || lowerName.includes('phone')) {
            return 'Call';
        } else if (lowerName.includes('facebook') || lowerName.includes('fb') || 
                  lowerName.includes('instagram') || lowerName.includes('social')) {
            return 'Social Media';
        }
        
        return 'Other';
    }

    getConfidenceClass(confidenceScore) {
        if (confidenceScore >= 0.9) return 'confidence-high';
        if (confidenceScore >= 0.7) return 'confidence-medium';
        return 'confidence-low';
    }

    getChannelIcon(channelType) {
        switch(channelType) {
            case 'Email': return 'utility:email';
            case 'SMS': return 'utility:sms';
            case 'Call': return 'utility:call';
            case 'Social Media': return 'utility:socialshare';
            default: return 'utility:campaign';
        }
    }

    handleApprove(event) {
        const suggestionId = event.target.dataset.suggestionId;
        this.isLoading = true;
        
        approveSuggestion({ suggestionId })
            .then(() => {
                this.showToast('Success', 'Campaigns grouped successfully! 🎉', 'success');
                return refreshApex(this.wiredSuggestionsResult);
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleReject(event) {
        const suggestionId = event.target.dataset.suggestionId;
        this.isLoading = true;
        
        rejectSuggestion({ suggestionId })
            .then(() => {
                this.showToast('Success', 'Suggestion rejected', 'success');
                return refreshApex(this.wiredSuggestionsResult);
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleEdit(event) {
        const suggestionId = event.target.dataset.suggestionId;
        const suggestion = this.suggestions.find(s => s.Id === suggestionId);
        
        this.editingSuggestion = suggestionId;
        this.newInitiativeName = suggestion.Suggested_Initiative_Name__c;
        this.selectedCampaigns = new Set();
        
        // Pre-select all campaigns
        suggestion.campaigns.forEach(campaign => {
            this.selectedCampaigns.add(campaign.campaignId);
        });
    }

    handleCancelEdit() {
        this.editingSuggestion = null;
        this.newInitiativeName = '';
        this.selectedCampaigns = new Set();
    }

    handleInitiativeNameChange(event) {
        this.newInitiativeName = event.target.value;
    }

    handleCampaignToggle(event) {
        const campaignId = event.target.dataset.campaignId;
        
        if (this.selectedCampaigns.has(campaignId)) {
            this.selectedCampaigns.delete(campaignId);
        } else {
            this.selectedCampaigns.add(campaignId);
        }
        
        // Force reactivity
        this.selectedCampaigns = new Set(this.selectedCampaigns);
    }

    handleSaveEdit() {
        if (!this.newInitiativeName.trim()) {
            this.showToast('Error', 'Initiative name is required', 'error');
            return;
        }

        if (this.selectedCampaigns.size === 0) {
            this.showToast('Error', 'Please select at least one campaign', 'error');
            return;
        }

        this.isLoading = true;
        
        modifySuggestion({ 
            suggestionId: this.editingSuggestion,
            newInitiativeName: this.newInitiativeName,
            campaignIds: Array.from(this.selectedCampaigns)
        })
            .then(() => {
                this.showToast('Success', 'Campaign group created with modifications! ✨', 'success');
                this.handleCancelEdit();
                return refreshApex(this.wiredSuggestionsResult);
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant,
            mode: variant === 'error' ? 'sticky' : 'dismissable'
        }));
    }

    get hasNoSuggestions() {
        return !this.isLoading && (!this.suggestions || this.suggestions.length === 0);
    }

    get isEditing() {
        return this.editingSuggestion !== null;
    }

    get editingSuggestionData() {
        return this.suggestions.find(s => s.Id === this.editingSuggestion);
    }

    get selectedCampaignsList() {
        if (!this.editingSuggestionData) return [];
        
        return this.editingSuggestionData.campaigns.map(campaign => ({
            ...campaign,
            isSelected: this.selectedCampaigns.has(campaign.campaignId)
        }));
    }
}