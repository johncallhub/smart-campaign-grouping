import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSuggestions from '@salesforce/apex/GroupingSuggestionController.getSuggestions';
import approveSuggestion from '@salesforce/apex/GroupingSuggestionController.approveSuggestion';
import rejectSuggestion from '@salesforce/apex/GroupingSuggestionController.rejectSuggestion';
import modifySuggestion from '@salesforce/apex/GroupingSuggestionController.modifySuggestion';

export default class CampaignGroupingSuggestions extends LightningElement {
    suggestions = [];
    isLoading = false;
    selectedSuggestion = null;
    showEditModal = false;
    editedInitiativeName = '';
    editedCampaignIds = [];
    wiredSuggestionsResult;

    @wire(getSuggestions)
    wiredSuggestions(result) {
        this.wiredSuggestionsResult = result;
        const { data, error } = result;
        
        if (data) {
            this.suggestions = data.map(suggestion => ({
                ...suggestion,
                formattedConfidence: Math.round(suggestion.Confidence_Score__c * 100),
                campaigns: this.formatCampaignList(suggestion.Campaign_Suggestion_Members__r),
                campaignCount: suggestion.Campaign_Suggestion_Members__r ? 
                    suggestion.Campaign_Suggestion_Members__r.length : 0,
                confidenceClass: this.getConfidenceClass(suggestion.Confidence_Score__c)
            }));
            this.isLoading = false;
        } else if (error) {
            this.showToast('Error', 'Error loading suggestions: ' + error.body.message, 'error');
            this.isLoading = false;
        }
    }

    formatCampaignList(members) {
        if (!members) return [];
        
        return members.map(member => ({
            id: member.Campaign__c,
            name: member.Campaign__r.Name,
            originalName: member.Original_Name__c,
            channelType: member.Channel_Type__c,
            channelIcon: this.getChannelIcon(member.Channel_Type__c),
            createdDate: this.formatDate(member.Campaign__r.CreatedDate)
        }));
    }

    getChannelIcon(channelType) {
        const iconMap = {
            'Email': 'standard:email',
            'SMS': 'standard:sms',
            'Call': 'standard:call',
            'Social Media': 'standard:social',
            'Other': 'standard:campaign'
        };
        return iconMap[channelType] || 'standard:campaign';
    }

    getConfidenceClass(confidence) {
        const percentage = confidence * 100;
        if (percentage >= 90) return 'slds-text-color_success';
        if (percentage >= 70) return 'slds-text-color_weak';
        return 'slds-text-color_error';
    }

    formatDate(dateString) {
        const date = new Date(dateString);
        return new Intl.DateTimeFormat('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        }).format(date);
    }

    handleApprove(event) {
        const suggestionId = event.target.dataset.suggestionId;
        this.isLoading = true;

        approveSuggestion({ suggestionId })
            .then(() => {
                this.showToast('Success', 'Campaigns grouped successfully', 'success');
                return refreshApex(this.wiredSuggestionsResult);
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
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
                this.isLoading = false;
            });
    }

    handleEdit(event) {
        const suggestionId = event.target.dataset.suggestionId;
        this.selectedSuggestion = this.suggestions.find(s => s.Id === suggestionId);
        this.editedInitiativeName = this.selectedSuggestion.Suggested_Initiative_Name__c;
        this.editedCampaignIds = this.selectedSuggestion.campaigns.map(c => c.id);
        this.showEditModal = true;
    }

    handleInitiativeNameChange(event) {
        this.editedInitiativeName = event.target.value;
    }

    handleCampaignSelection(event) {
        const campaignId = event.target.dataset.campaignId;
        if (event.target.checked) {
            if (!this.editedCampaignIds.includes(campaignId)) {
                this.editedCampaignIds.push(campaignId);
            }
        } else {
            this.editedCampaignIds = this.editedCampaignIds.filter(id => id !== campaignId);
        }
    }

    handleSaveEdit() {
        if (!this.editedInitiativeName || this.editedCampaignIds.length === 0) {
            this.showToast('Error', 'Please provide an initiative name and select at least one campaign', 'error');
            return;
        }

        this.isLoading = true;

        modifySuggestion({
            suggestionId: this.selectedSuggestion.Id,
            newInitiativeName: this.editedInitiativeName,
            campaignIds: this.editedCampaignIds
        })
            .then(() => {
                this.showToast('Success', 'Campaigns grouped with modifications', 'success');
                this.closeEditModal();
                return refreshApex(this.wiredSuggestionsResult);
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
                this.isLoading = false;
            });
    }

    closeEditModal() {
        this.showEditModal = false;
        this.selectedSuggestion = null;
        this.editedInitiativeName = '';
        this.editedCampaignIds = [];
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }

    get hasNoSuggestions() {
        return !this.isLoading && this.suggestions.length === 0;
    }

    get editModalCampaigns() {
        if (!this.selectedSuggestion) return [];
        
        return this.selectedSuggestion.campaigns.map(campaign => ({
            ...campaign,
            isSelected: this.editedCampaignIds.includes(campaign.id)
        }));
    }
}