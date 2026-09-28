// 友情链接数据配置。修改后重新构建网站即可更新 /friends/ 页面。
// 来源：旧站「友人帐」页面 https://www.intotw.cn/友人帐/

export interface FriendItem {
	id: number;
	title: string;
	imgurl: string;
	desc: string;
	siteurl: string;
	tags: string[];
}

export const friendsData: FriendItem[] = [
	{
		id: 1,
		title: "Luminous' Home",
		imgurl: "https://cdn.luotianyi.vc/wp-content/uploads/2020-02-13_09-22-57.jpg",
		desc: "一条很咸很咸的🐟，欢迎投喂~",
		siteurl: "https://luotianyi.vc/",
		tags: ["友链"],
	},
	{
		id: 2,
		title: "维基萌",
		imgurl: "https://www.wikimoe.com/upload/siteImg/siteFavicon.png",
		desc: "萌即是正义！时不时分享一些ACG活动记录与有趣代码的小站！",
		siteurl: "https://www.wikimoe.com/",
		tags: ["友链"],
	},
];

export function getFriendsList(): FriendItem[] {
	return friendsData;
}

export function getShuffledFriendsList(): FriendItem[] {
	const shuffled = [...friendsData];
	for (let i = shuffled.length - 1; i > 0; i--) {
		const j = Math.floor(Math.random() * (i + 1));
		[shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
	}
	return shuffled;
}
