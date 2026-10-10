import { can, isStaff, isSuperAdmin } from '@/lib/permissions';
import { UserProfile } from '@/lib/types';

export type AdminNavItem = {
  title: string;
  href: string;
  icon: string;
  visible: (profile: UserProfile | null | undefined) => boolean;
};

// Simplified visible admin menu items (Owner rule: keep it simple for a small gym)
export const nav: AdminNavItem[] = [
  {
    title: 'Overview',
    href: '/admin',
    icon: 'dashboard',
    visible: (p) => isStaff(p),
  },
  {
    title: 'Members',
    href: '/admin/members',
    icon: 'group',
    visible: (p) => can(p, 'manageMembers'),
  },
  {
    title: 'Bookings',
    href: '/admin/bookings',
    icon: 'assignment_turned_in',
    visible: (p) =>
      can(p, 'refund') ||
      can(p, 'bookForMember') ||
      can(p, 'viewRevenue') ||
      can(p, 'checkIn'),
  },
  {
    title: 'Sessions',
    href: '/admin/offers',
    icon: 'local_offer',
    visible: (p) => can(p, 'manageOffers'),
  },
  {
    title: 'Payments',
    href: '/admin/payments',
    icon: 'credit_card',
    visible: (p) =>
      can(p, 'refund') ||
      can(p, 'viewRevenue') ||
      can(p, 'bookForMember') ||
      can(p, 'manageStore'),
  },
  {
    title: 'Store',
    href: '/admin/store',
    icon: 'shopping_bag',
    visible: (p) => can(p, 'manageStore'),
  },
  {
    title: 'Kids Photos',
    href: '/admin/gallery',
    icon: 'photo_library',
    visible: (p) => can(p, 'manageContent'),
  },
  {
    title: 'Settings',
    href: '/admin/settings',
    icon: 'settings',
    visible: (p) => isSuperAdmin(p),
  },
];

// Hidden from sidebar menu, but routes remain fully accessible via Gym Settings "More" list
export const hiddenRoutes: AdminNavItem[] = [
  {
    title: 'Announcements',
    href: '/admin/notifications',
    icon: 'notifications',
    visible: (p) => can(p, 'manageContent'),
  },
  {
    title: 'Waiver',
    href: '/admin/waiver',
    icon: 'assignment_turned_in',
    visible: (p) => can(p, 'manageContent'),
  },
  {
    title: 'Legal Pages',
    href: '/admin/legal',
    icon: 'gavel',
    visible: (p) => can(p, 'manageContent'),
  },
  {
    title: 'Staff',
    href: '/admin/staff',
    icon: 'admin_panel_settings',
    visible: (p) => isSuperAdmin(p),
  },
];

export const allAdminRoutes: AdminNavItem[] = [...nav, ...hiddenRoutes];

export type AdminAccessResult = {
  allowed: boolean;
  notice?: string;
  item?: AdminNavItem;
};

export function adminAccess(
  profile: UserProfile | null | undefined,
  path: string
): AdminAccessResult {
  if (!isStaff(profile)) {
    return {
      allowed: false,
      notice: 'Administrator access is required.',
    };
  }

  const normalized = path.replace(/\.html$/, '').replace(/\/$/, '') || '/admin';

  // Find most specific matching nav item across all admin routes
  const matched = [...allAdminRoutes]
    .filter((item) => item.href !== '/admin')
    .sort((a, b) => b.href.length - a.href.length)
    .find(
      (item) =>
        normalized === item.href || normalized.startsWith(item.href + '/')
    );

  const activeItem = matched || allAdminRoutes.find((item) => item.href === '/admin');

  if (!activeItem) {
    return {
      allowed: false,
      notice: "You don't have access to this page.",
    };
  }

  if (activeItem.visible(profile)) {
    return {
      allowed: true,
      item: activeItem,
    };
  }

  return {
    allowed: false,
    notice: "You don't have access to this page.",
    item: activeItem,
  };
}
