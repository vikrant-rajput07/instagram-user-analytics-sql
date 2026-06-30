-- OBJECTIVE QUESTIONS --

-- Q1: Are there any tables with duplicate or missing null values? If so, how would you handle them?

-- Checking for DUPLICATE values in the users table
SELECT username, COUNT(*)
FROM users
GROUP BY username
HAVING COUNT(*) > 1;

-- Checking for NULL values in the users table
SELECT *
FROM users
WHERE username IS NULL;

-- Q2: What is the distribution of user activity levels (e.g., number of posts, likes, comments) across the user base?

SELECT activity_level, COUNT(*) AS user_count
FROM (
    SELECT u.id, u.username,
           COUNT(DISTINCT p.id) AS num_posts,
           COUNT(DISTINCT l.photo_id) AS num_likes,
           COUNT(DISTINCT c.id) AS num_comments,
    CASE 
	WHEN COUNT(DISTINCT p.id) = 0 
	AND COUNT(DISTINCT l.photo_id) = 0 
	AND COUNT(DISTINCT c.id) = 0 THEN 'Inactive'
	WHEN COUNT(DISTINCT p.id) <= 2 
	AND COUNT(DISTINCT l.photo_id) <= 5 
	AND COUNT(DISTINCT c.id) <= 3 THEN 'Low Activity'
    WHEN COUNT(DISTINCT p.id) BETWEEN 3 AND 5 
	OR COUNT(DISTINCT l.photo_id) BETWEEN 6 AND 15
	OR COUNT(DISTINCT c.id) BETWEEN 4 AND 10 THEN 'Medium Activity'
    ELSE 'High Activity' END AS activity_level
    FROM users u
    LEFT JOIN photos p ON u.id = p.user_id
    LEFT JOIN likes l ON u.id = l.user_id
    LEFT JOIN comments c ON u.id = c.user_id
    GROUP BY u.id, u.username
) t
GROUP BY activity_level
ORDER BY user_count DESC;

-- Q3: Calculate the average number of tags per post (photo_tags and photos tables)

SELECT Round(AVG(tag_count),2) AS avg_tags_per_post
FROM (SELECT p.id, COUNT(pt.tag_id) AS tag_count
FROM photos p
LEFT JOIN photo_tags pt 
ON p.id = pt.photo_id 
GROUP BY p.id) t;

-- Q4: Identify the top users with the highest engagement rates (likes, comments) on their posts and rank them.

SELECT u.id AS user_id, u.username,
	COUNT(DISTINCT p.id) AS total_posts,
    COUNT(DISTINCT l.user_id, l.photo_id) AS total_likes,
    COUNT(DISTINCT c.id) AS total_comments,
    (COUNT(DISTINCT l.user_id, l.photo_id) + COUNT(DISTINCT c.id)) AS total_engagement,
    RANK() OVER(ORDER BY (COUNT(DISTINCT l.user_id, l.photo_id) + COUNT(DISTINCT c.id)) DESC) AS user_rank
FROM users u
LEFT JOIN photos p 
ON u.id = p.user_id
LEFT JOIN likes l 
ON p.id = l.photo_id  
LEFT JOIN comments c 
ON p.id = c.photo_id  
GROUP BY u.id, u.username;

-- Q5: Which users have the highest number of followers and followings? 

SELECT u.id AS user_id, u.username, 
	COUNT(DISTINCT f1.follower_id) AS total_followers,
	COUNT(DISTINCT f2.followee_id) AS total_followings
FROM users u 
LEFT JOIN follows f1
ON u.id = f1.followee_id 
LEFT JOIN follows f2
ON u.id = f2.follower_id
GROUP BY u.id, u.username
ORDER BY total_followers DESC, total_followings DESC;

-- Q6: Calculate the average engagement rate (likes, comments) per post for each user. 

WITH Followers AS (
                   SELECT followee_id AS user_id, COUNT(*) AS total_followers
                   FROM follows
                   GROUP BY followee_id
)
SELECT u.id AS user_id, u.username,
COUNT(DISTINCT p.id) AS total_posts,
COUNT(DISTINCT l.user_id) AS total_likes,
COUNT(DISTINCT c.id) AS total_comments,
COALESCE(f.total_followers, 0) AS total_followers,
ROUND((COUNT(DISTINCT l.user_id) + COUNT(DISTINCT c.id)) / NULLIF(COUNT(DISTINCT p.id), 0), 2) AS avg_engagement_per_post
FROM users u
LEFT JOIN photos p
ON u.id = p.user_id
LEFT JOIN likes l
ON p.id = l.photo_id
LEFT JOIN comments c
ON p.id = c.photo_id
LEFT JOIN Followers f
ON u.id = f.user_id
GROUP BY u.id, u.username, f.total_followers
ORDER BY user_id;

-- Q7: Get the list of users who have never liked any post (users and likes tables) 

SELECT u.id, u.username
FROM users u
LEFT JOIN likes l 
ON u.id = l.user_id
WHERE l.user_id IS NULL;

-- Q8: How can you leverage user-generated content (posts, hashtags, photo tags) to create more personalised and engaging ad campaigns? 

SELECT t.tag_name, COUNT(pt.photo_id) AS tag_usage_count
FROM tags t
JOIN photo_tags pt
ON t.id = pt.tag_id
GROUP BY t.tag_name
ORDER BY tag_usage_count DESC
LIMIT 10;

-- Q9. Are there any correlations between user activity levels and specific content types (e.g., photos, videos, reels)? How can this information guide content creation and curation strategies? 

-- No SQL query is required.
-- Answer provided in the documentation file.

-- Q10: Calculate the total number of likes, comments, and photo tags for each user.

SELECT u.id AS user_id, u.username,
    COUNT(DISTINCT l.user_id) AS total_likes,
    COUNT(DISTINCT c.id) AS total_comments,
    COUNT(DISTINCT pt.tag_id) AS total_photo_tags
FROM users u
LEFT JOIN photos p 
ON u.id = p.user_id
LEFT JOIN likes l 
ON p.id = l.photo_id
LEFT JOIN comments c 
ON p.id = c.photo_id
LEFT JOIN photo_tags pt 
ON p.id = pt.photo_id
GROUP BY u.id, u.username;

-- Q11: Rank users based on their total engagement (likes, comments, shares) over a month. 

SELECT u.id AS user_id, u.username,
    COUNT(DISTINCT l.user_id) AS total_likes,
    COUNT(DISTINCT c.id) AS total_comments,
    (COUNT(DISTINCT l.user_id) + COUNT(DISTINCT c.id)) AS total_engagement,
    RANK() OVER(ORDER BY (COUNT(DISTINCT l.user_id) + COUNT(DISTINCT c.id)) DESC) AS user_rank
FROM users u
LEFT JOIN photos p 
ON u.id = p.user_id
LEFT JOIN likes l 
ON p.id = l.photo_id 
AND MONTH(l.created_at) = 6
LEFT JOIN comments c 
ON p.id = c.photo_id 
AND MONTH(c.created_at) = 6
GROUP BY u.id, u.username;

-- Q12: Retrieve the hashtags that have been used in posts with the highest average number of likes. Use a CTE to calculate the average likes for each hashtag first.

WITH Hashtag_Likes AS (
                       SELECT t.tag_name, 
                       COUNT(l.photo_id) AS total_likes, 
                       COUNT(DISTINCT p.id) AS total_posts
                       FROM tags t
					   JOIN photo_tags pt ON t.id = pt.tag_id
                       JOIN photos p ON pt.photo_id = p.id
					   LEFT JOIN likes l ON p.id = l.photo_id
					   GROUP BY t.tag_name
),
Average_Likes_Per_Hashtag AS (
                              SELECT tag_name, 
							  (total_likes / total_posts) AS avg_likes
							  FROM Hashtag_Likes
)
SELECT tag_name, ROUND(avg_likes, 2) AS avg_likes
FROM Average_Likes_Per_Hashtag
ORDER BY avg_likes DESC
Limit 5;

-- Q13: Retrieve the users who have started following someone after being followed by that person.

SELECT f1.follower_id, f1.followee_id
FROM follows f1
JOIN follows f2 
ON f1.follower_id = f2.followee_id 
AND f1.followee_id = f2.follower_id
WHERE f1.created_at > f2.created_at;

-- Subjective Questions --

-- Q1: Based on user engagement and activity levels, which users would you consider the most loyal or valuable? How would you reward or incentivize these users?

WITH TotalLikes AS (
	SELECT u.id, COUNT(DISTINCT l.user_id, l.photo_id) AS total_likes
    FROM users u
    LEFT JOIN likes l 
    ON u.id = l.user_id
    GROUP BY u.id
),
TotalComments AS (
    SELECT u.id, COUNT(DISTINCT c.id) AS total_comments
    FROM users u
    LEFT JOIN comments c 
    ON u.id = c.user_id
    GROUP BY u.id
),
PhotosPosted AS (
    SELECT user_id, COUNT(id) AS total_photos_posted
    FROM photos
    GROUP BY user_id
),
Followers AS (
    SELECT followee_id AS user_id, COUNT(follower_id) AS total_followers
    FROM follows
    GROUP BY followee_id
),
UniqueTags AS (
    SELECT p.user_id, COUNT(DISTINCT pt.tag_id) AS unique_tags_used
    FROM photos p
    LEFT JOIN photo_tags pt
    ON p.id = pt.photo_id
    GROUP BY p.user_id
)
SELECT u.id AS user_id, u.username,
    COALESCE(tl.total_likes, 0) AS total_likes,
    COALESCE(tc.total_comments, 0) AS total_comments,
    COALESCE(pp.total_photos_posted, 0) AS total_photos_posted,
    COALESCE(f.total_followers, 0) AS total_followers,
    COALESCE(ut.unique_tags_used, 0) AS unique_tags_used,
    (COALESCE(tl.total_likes, 0) + COALESCE(tc.total_comments, 0)) AS total_engagement
FROM users u
LEFT JOIN TotalLikes tl 
ON u.id = tl.id
LEFT JOIN TotalComments tc
 ON u.id = tc.id
LEFT JOIN PhotosPosted pp 
ON u.id = pp.user_id
LEFT JOIN Followers f 
ON u.id = f.user_id
LEFT JOIN UniqueTags ut 
ON u.id = ut.user_id
GROUP BY u.id, u.username
HAVING total_photos_posted > 0
ORDER BY total_engagement DESC, total_followers DESC, total_photos_posted DESC
LIMIT 10;

-- Q2: For inactive users, what strategies would you recommend to re-engage them and encourage them to start posting or engaging again?

-- No SQL query is required.
-- Answer provided in the documentation file.

-- Q3: Which hashtags or content topics have the highest engagement rates? How can this information guide content strategy and ad campaigns?

WITH PhotoEngagement AS (
                         SELECT p.id AS photo_id,
                         COUNT(l.user_id) AS total_likes,
                         COUNT(c.id) AS total_comments,
						 COUNT(l.user_id) + COUNT(c.id) AS total_engagement
                         FROM photos p
                         LEFT JOIN likes l ON p.id = l.photo_id
						 LEFT JOIN comments c ON p.id = c.photo_id
                         GROUP BY p.id
),
HashtagEngagement AS (
					  SELECT t.id AS tag_id, t.tag_name,
                      SUM(pe.total_engagement) AS total_engagement,
					  COUNT(DISTINCT pt.photo_id) AS total_photos,
                      ROUND(SUM(pe.total_engagement) / COUNT(DISTINCT pt.photo_id), 2) AS engagement_rate
                      FROM tags t
					  JOIN photo_tags pt ON t.id = pt.tag_id
					  JOIN PhotoEngagement pe ON pt.photo_id = pe.photo_id
                      GROUP BY t.id, t.tag_name
)
SELECT tag_name, total_photos, total_engagement, engagement_rate
FROM HashtagEngagement
ORDER BY engagement_rate DESC
LIMIT 10;

-- Q4:  Are there any patterns or trends in user engagement based on demographics (age, location, gender) or posting times? How can these insights inform targeted marketing campaigns?

SELECT HOUR(p.created_dat) AS post_hour,
    DAYOFWEEK(p.created_dat) AS post_day,
    COUNT(DISTINCT p.id) AS total_posts,
    COUNT(DISTINCT l.user_id, l.photo_id) AS total_likes,
    COUNT(DISTINCT c.id) AS total_comments
FROM photos p
LEFT JOIN likes l 
ON p.id = l.photo_id
LEFT JOIN comments c 
ON p.id = c.photo_id
GROUP BY post_hour, post_day
ORDER BY total_posts DESC;

-- Q5: Based on follower counts and engagement rates, which users would be ideal candidates for influencer marketing campaigns? How would you approach and collaborate with these influencers? 

WITH TotalLikes AS (
                    SELECT user_id, COUNT(*) AS total_likes
                    FROM likes
                    GROUP BY user_id
),
TotalComments AS (
                  SELECT user_id, COUNT(*) AS total_comments
                  FROM comments
                  GROUP BY user_id
),
PhotosPosted AS (
                 SELECT user_id, COUNT(*) AS total_posts
                 FROM photos
                 GROUP BY user_id
),
Followers AS (
			  SELECT followee_id AS user_id, COUNT(*) AS total_followers
              FROM follows
			  GROUP BY followee_id
)
SELECT u.id AS user_id, u.username,
COALESCE(pp.total_posts,0) AS total_posts,
COALESCE(tl.total_likes,0) AS total_likes,
COALESCE(tc.total_comments,0) AS total_comments,
COALESCE(f.total_followers,0) AS total_followers,
ROUND((COALESCE(tl.total_likes,0) + COALESCE(tc.total_comments,0)) / NULLIF(COALESCE(pp.total_posts,0),0),2) AS engagement_rate
FROM users u
LEFT JOIN TotalLikes tl
ON u.id = tl.user_id
LEFT JOIN TotalComments tc
ON u.id = tc.user_id
LEFT JOIN PhotosPosted pp
ON u.id = pp.user_id
LEFT JOIN Followers f
ON u.id = f.user_id
WHERE COALESCE(pp.total_posts,0) > 0
ORDER BY engagement_rate DESC, total_followers DESC
LIMIT 10;

-- Q6: Based on user behavior and engagement data, how would you segment the user base for targeted marketing campaigns or personalized recommendations?

SELECT u.id AS user_id, u.username,
COUNT(DISTINCT p.id) AS total_posts,
COUNT(DISTINCT l.photo_id) AS total_likes,
COUNT(DISTINCT c.id) AS total_comments,
CASE 
WHEN COUNT(DISTINCT p.id) = 0 
AND COUNT(DISTINCT l.photo_id) = 0 
AND COUNT(DISTINCT c.id) = 0 THEN 'Inactive Users'
WHEN COUNT(DISTINCT p.id) <= 2 
AND COUNT(DISTINCT l.photo_id) <= 5 
AND COUNT(DISTINCT c.id) <= 3 THEN 'Low Activity Users'
WHEN COUNT(DISTINCT p.id) BETWEEN 3 AND 5 
OR COUNT(DISTINCT l.photo_id) BETWEEN 6 AND 15 
OR COUNT(DISTINCT c.id) BETWEEN 4 AND 10 THEN 'Moderately Active Users'
ELSE 'Highly Active Users' END AS user_segment
FROM users u
LEFT JOIN photos p 
ON u.id = p.user_id
LEFT JOIN likes l 
ON u.id = l.user_id
LEFT JOIN comments c 
ON u.id = c.user_id
GROUP BY u.id, u.username;

-- Q7: If data on ad campaigns (impressions, clicks, conversions) is available, how would you measure their effectiveness and optimize future campaigns?

-- No SQL query is required.
-- Answer provided in the documentation file.

-- Q8: How can you use user activity data to identify potential brand ambassadors or advocates who could help promote Instagram's initiatives or events?

-- No SQL query is required.
-- Answer provided in the documentation file.

-- Q9: How would you approach this problem, if the objective and subjective questions weren't given?

-- No SQL query is required.
-- Answer provided in the documentation file.

-- Q10: Assuming there's a "User_Interactions" table tracking user engagements, how can you update the "Engagement_Type" column to change all instances of "Like" to "Heart" to align with Instagram's terminology?

UPDATE User_Interactions
SET Engagement_Type = 'Heart'
WHERE Engagement_Type = 'Like';