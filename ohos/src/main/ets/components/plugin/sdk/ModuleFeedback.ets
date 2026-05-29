export interface FeedbackWidgetInfo {
  id: string;
  type: string;
  name: string;
}

export interface StarRatingDialogTexts {
  title: string;
  message: string;
  dismiss: string;
}

export class ModuleFeedback {
  private widgets: Array<FeedbackWidgetInfo> = [
    { id: 'ohos_rating_widget', type: 'rating', name: 'OHOS Rating Widget' },
    { id: 'ohos_nps_widget', type: 'nps', name: 'OHOS NPS Widget' },
    { id: 'ohos_survey_widget', type: 'survey', name: 'OHOS Survey Widget' }
  ];

  private starRatingTitle: string = '';
  private starRatingMessage: string = '';
  private starRatingDismiss: string = '';

  getAvailableWidgets(): Array<FeedbackWidgetInfo> {
    const copied: Array<FeedbackWidgetInfo> = [];
    for (let i = 0; i < this.widgets.length; i++) {
      copied.push(this.widgets[i]);
    }
    return copied;
  }

  setStarRatingDialogTexts(title: string, message: string, dismiss: string): void {
    this.starRatingTitle = title;
    this.starRatingMessage = message;
    this.starRatingDismiss = dismiss;
  }

  getStarRatingDialogTexts(): StarRatingDialogTexts {
    const texts: StarRatingDialogTexts = {
      title: this.starRatingTitle,
      message: this.starRatingMessage,
      dismiss: this.starRatingDismiss
    };
    return texts;
  }

  findWidgetById(widgetId: string): FeedbackWidgetInfo | null {
    for (let i = 0; i < this.widgets.length; i++) {
      const info = this.widgets[i];
      if (info.id === widgetId) {
        return info;
      }
    }
    return null;
  }
}
