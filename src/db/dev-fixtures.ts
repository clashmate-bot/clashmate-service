export interface GuildFixture {
  guildId: string;
  name: string;
  botKind: 'public' | 'custom';
}

export interface GuildCategoryFixture {
  guildId: string;
  name: string;
  position: number;
}

export interface GuildClanFixture {
  guildId: string;
  clanTag: string;
  categoryName: string;
  displayName: string;
  position: number;
}

export interface UserProfileFixture {
  userId: string;
  displayName: string;
  timezone: string;
  locale: string;
}

export interface PlayerFixture {
  playerTag: string;
  name: string;
  clanTag: string;
  townHallLevel: number;
  trophies: number;
}

export interface LinkFixture {
  playerTag: string;
  playerName: string;
  userId: string;
  guildId: string;
  linkedByUserId: string;
  isVerified: boolean;
  linkOrder: number;
}

export const guildFixtures: GuildFixture[] = [
  {
    guildId: '111111111111111111',
    name: 'ClashMate Dev Guild',
    botKind: 'public',
  },
];

export const guildCategoryFixtures: GuildCategoryFixture[] = [
  {
    guildId: '111111111111111111',
    name: 'Main Family',
    position: 0,
  },
  {
    guildId: '111111111111111111',
    name: 'Feeder',
    position: 1,
  },
];

export const guildClanFixtures: GuildClanFixture[] = [
  {
    guildId: '111111111111111111',
    clanTag: '#2PP',
    categoryName: 'Main Family',
    displayName: 'ClashMate Alpha',
    position: 0,
  },
  {
    guildId: '111111111111111111',
    clanTag: '#2QQ',
    categoryName: 'Feeder',
    displayName: 'ClashMate Bravo',
    position: 1,
  },
];

export const userProfileFixtures: UserProfileFixture[] = [
  {
    userId: '222222222222222222',
    displayName: 'Angga',
    timezone: 'Asia/Jakarta',
    locale: 'en',
  },
  {
    userId: '333333333333333333',
    displayName: 'CoLeader',
    timezone: 'UTC',
    locale: 'en',
  },
  {
    userId: '444444444444444444',
    displayName: 'MemberOne',
    timezone: 'Asia/Singapore',
    locale: 'en',
  },
];

export const playerFixtures: PlayerFixture[] = [
  {
    playerTag: '#AAA111',
    name: 'Electro Owl',
    clanTag: '#2PP',
    townHallLevel: 16,
    trophies: 5800,
  },
  {
    playerTag: '#BBB222',
    name: 'Ice Golem',
    clanTag: '#2PP',
    townHallLevel: 15,
    trophies: 5400,
  },
  {
    playerTag: '#CCC333',
    name: 'Royal Yak',
    clanTag: '#2QQ',
    townHallLevel: 14,
    trophies: 5100,
  },
];

export const linkFixtures: LinkFixture[] = [
  {
    playerTag: '#AAA111',
    playerName: 'Electro Owl',
    userId: '222222222222222222',
    guildId: '111111111111111111',
    linkedByUserId: '222222222222222222',
    isVerified: true,
    linkOrder: 0,
  },
  {
    playerTag: '#BBB222',
    playerName: 'Ice Golem',
    userId: '333333333333333333',
    guildId: '111111111111111111',
    linkedByUserId: '222222222222222222',
    isVerified: false,
    linkOrder: 1,
  },
];
