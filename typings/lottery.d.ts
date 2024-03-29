export interface RewardRule {
  matchNumber: number;
  rewardValue: number;
}

export interface Lottery {
  id: string;
  verboseName: string;
  picture: string;
  numberOfItems: number;
  minValuePerItem: number;
  maxValuePerItem: number;
  periodDays: number[];
  periodHourOfDays: number;
  maxNumberTicketsPerBuy: number;
  pricePerTicket: number;
  treasuryFeePercent: number;
  amountInjectNextRoundPercent: number;
  discountPercent: number;
  rewardRules: RewardRule[];
}
