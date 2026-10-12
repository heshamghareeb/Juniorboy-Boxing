export type Row = { id: string; [key: string]: any };
export type StaffRole = 'admin' | 'superAdmin';
export type UserRole = 'member' | StaffRole;

export type Permission =
  | 'manageOffers'
  | 'checkIn'
  | 'approveRequests'
  | 'cancelOccurrences'
  | 'refund'
  | 'bookForMember'
  | 'viewRevenue'
  | 'manageMembers'
  | 'manageStore'
  | 'manageContent';

export type PermissionsMap = Partial<Record<Permission, boolean>>;

export type UserProfile = Row & {
  fullName?: string;
  email?: string;
  phone?: string;
  address?: string;
  role?: UserRole | 'coach' | string;
  isActive?: boolean;
  permissions?: PermissionsMap;
  notificationPreferences?: {
    push?: boolean;
    email?: boolean;
    offers?: boolean;
    reminders?: boolean;
    marketing?: boolean;
  };
  sessionsRemaining?: number;
  sessionsReserved?: number;
  privateSessionsRemaining?: number;
  privateSessionsReserved?: number;
  groupSessionsRemaining?: number;
  groupSessionsReserved?: number;
  duoSessionsRemaining?: number;
  duoSessionsReserved?: number;
  memberSince?: any;
  avatarUrl?: string;
  childName?: string;
  childAge?: number;
};

export type Plan = Row & { name: string; price: number; priceLabel: string; perSessionLabel: string; isRecommended: boolean; sortOrder: number; sessionCount: number | null; planType: string; isActive: boolean };
export const plans: Plan[] = [
  { id:'single', name:'Single Session', price:8000, priceLabel:'$80', perSessionLabel:'$80 / session', sessionCount:1, planType:'package', isRecommended:false, sortOrder:0, isActive:true },
  { id:'five', name:'5 Session Pack', price:35000, priceLabel:'$350', perSessionLabel:'$70 / session', sessionCount:5, planType:'package', isRecommended:false, sortOrder:1, isActive:true },
  { id:'ten', name:'10 Session Pack', price:60000, priceLabel:'$600', perSessionLabel:'$60 / session', sessionCount:10, planType:'package', isRecommended:true, sortOrder:2, isActive:true },
  { id:'group', name:'Small Group Training', price:3500, priceLabel:'$35', perSessionLabel:'/ hour per person', sessionCount:null, planType:'hourly', isRecommended:false, sortOrder:3, isActive:true },
  { id:'partner', name:'Partner Training', price:6000, priceLabel:'$60', perSessionLabel:'/ hour per person', sessionCount:null, planType:'hourly', isRecommended:false, sortOrder:4, isActive:true },
];
export const gym = { gymName:'Junior Boy Boxing', address:'', coachName:'Coach Sharif', aboutText:'We help kids and teens grow through boxing. Every session builds skills, confidence and the discipline to keep going.', phone:'', email:'email@juniorboyboxing.com', cancellationPolicyHours:24, operatingHours:{}, socialLinks:{instagram:'',facebook:'',tiktok:'',youtube:''} };

export type GalleryPhoto = Row & {
  imageUrl: string;
  storagePath: string;
  caption?: string | null;
  isVisible: boolean;
  sortOrder: number;
  createdAt: any;
  updatedAt: any;
  createdBy?: string;
};

export type SessionTimeSlot = {
  startTime: string;
  endTime: string;
  maxParticipants?: number;
  joinedUserIds?: string[];
};
