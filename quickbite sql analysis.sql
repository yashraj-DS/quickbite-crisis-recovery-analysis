/*==============================================================
            QUICKBITE EXPRESS
        BUSINESS RECOVERY ANALYSIS
==============================================================

Objective:
Answer the Primary & Secondary Business Questions
provided in the Codebasics Challenge.

==============================================================*/
/*
Q1. Monthly Orders: 
Compare total orders across pre-crisis (Jan–May 2025) vs crisis 
(Jun–Sep 2025). How severe is the decline? */
SELECT PHASE,COUNT(*) AS 'TOTAL ORDERS' FROM (SELECT *,CASE WHEN ORDERS.ORDER_TIMESTAMP <'2025-06-01' AND ORDERS.ORDER_TIMESTAMP >='2025-01-01' THEN 'Pre-Crisis' WHEN ORDERS.ORDER_TIMESTAMP >='2025-06-01' AND ORDERS.ORDER_TIMESTAMP <'2025-10-01' THEN 'Crisis' END AS 'PHASE' FROM ORDERS) T GROUP BY PHASE ORDER BY COUNT(*);
/*
Q2. Which top 5 city groups experienced the highest percentage decline in orders 
during the crisis period compared to the pre-crisis period? .*/
WITH ORDER_STAGE AS (
SELECT C.CITY,CASE WHEN O.ORDER_TIMESTAMP <'2025-06-01' AND O.ORDER_TIMESTAMP >='2025-01-01' THEN 'Pre_Crisis' WHEN O.ORDER_TIMESTAMP >='2025-06-01' AND O.ORDER_TIMESTAMP <'2025-10-01' THEN 'Crisis' END AS 'PHASE'
FROM ORDERS O JOIN CUSTOMER C ON O.CUSTOMER_ID = C.CUSTOMER_ID WHERE O.ORDER_TIMESTAMP>='2025-01-01' AND O.ORDER_TIMESTAMP<'2025-10-01'),
CITY_ORDER AS (SELECT CITY, SUM(CASE WHEN PHASE = 'Pre_Crisis' THEN 1 ELSE 0 end ) AS 'Pre_Crisis',SUM(CASE WHEN PHASE = 'Crisis' THEN 1 ELSE 0 END) AS 'Crisis' FROM ORDER_STAGE GROUP BY CITY)
SELECT *, ROUND(((Pre_Crisis-Crisis)*100)/Pre_Crisis,2) AS 'Decline %' FROM CITY_ORDER ORDER BY ROUND(((Pre_Crisis-Crisis)*100)/Pre_Crisis,2) DESC LIMIT 5;

/*==============================================================
Q3. Restaurant Performance
Among restaurants with at least 50 pre-crisis orders, which top 10 high-volume 
restaurants experienced the largest percentage decline in order counts during 
the crisis period? 
==============================================================*/
with restaurant_filter as (select * from restaurant where restaurant_id in(select restaurant_id from  (select r.restaurant_id as restaurant_id
from orders o join restaurant r on o.restaurant_id = r.restaurant_id  where O.ORDER_TIMESTAMP <'2025-06-01' AND O.ORDER_TIMESTAMP >='2025-01-01' group by r.restaurant_id having count(*) >=50 order by count(*) desc limit 10) as t)),
order_phase as (SELECT R.RESTAURANT_ID AS RESTAURANT_ID,O.ORDER_ID AS ORDER_ID,CASE WHEN O.ORDER_TIMESTAMP <'2025-06-01' AND O.ORDER_TIMESTAMP >='2025-01-01' THEN 'Pre-Crisis' WHEN O.ORDER_TIMESTAMP >='2025-06-01' AND O.ORDER_TIMESTAMP <'2025-10-01' THEN 'Crisis' END AS 'PHASE' FROM ORDERS O INNER JOIN RESTAURANT_FILTER R ON O.RESTAURANT_ID = R.RESTAURANT_ID),
RESTAURANT_ORDER AS (SELECT RESTAURANT_ID, SUM(CASE WHEN PHASE='Pre-Crisis' THEN 1 ELSE 0 END) AS 'Pre_Crisis',SUM(CASE WHEN PHASE='Crisis' THEN 1 ELSE 0 END) AS 'Crisis' FROM ORDER_PHASE GROUP BY RESTAURANT_ID)
SELECT *, ROUND(((Pre_Crisis-Crisis)*100)/Pre_Crisis,2) AS 'Decline %' FROM RESTAURANT_ORDER ORDER BY ROUND(((Pre_Crisis-Crisis)*100)/Pre_Crisis,2) DESC LIMIT 10;
-- Empty bcz there is no restaurants having 50 or 50+ orders in pre-crisis bcz maximum is 20
/*select r.restaurant_id,count(r.restaurant_id) from orders o join restaurant r on o.restaurant_id = r.restaurant_id 
where O.ORDER_TIMESTAMP <'2025-06-01' AND O.ORDER_TIMESTAMP >='2025-01-01' group by r.restaurant_id order by count(*) desc limit 10;*/

/*==============================================================
Q4. Cancellation Analysis:
What is the cancellation rate trend pre-crisis vs crisis, 
and which cities are most affected?
==============================================================*/
with customer_order as (select c.customer_id,c.city,o.order_id,o.is_cancelled,
CASE WHEN O.ORDER_TIMESTAMP <'2025-06-01' AND O.ORDER_TIMESTAMP >='2025-01-01' THEN 'Pre-Crisis' WHEN O.ORDER_TIMESTAMP >='2025-06-01' AND O.ORDER_TIMESTAMP <'2025-10-01' THEN 'Crisis' END AS 'PHASE' 
from orders o inner join customer c on o.customer_id = c.customer_id where o.order_timestamp <'2025-10-01' AND o.order_timestamp >='2025-01-01'),
aggregated as (select city,phase,sum(case when lower(is_cancelled) = 'y' then 1 else 0 end) as cancelled, sum(case when lower(is_cancelled) = 'n' then 1 else 0 end) as delivered,count(order_id) as total_orders from customer_order group by city,phase),
cancellation_pct as (select city,phase,round(((cancelled*100)/total_orders),2) as cancellation_pct from aggregated order by cancellation_pct desc)
select city,phase,cancellation_pct from cancellation_pct ORDER BY MAX(CASE WHEN phase = 'Crisis' THEN cancellation_pct ELSE 0 END) OVER(PARTITION BY city) DESC,phase asc;

/*==============================================================
Q5. Delivery SLA:
Measure average delivery time across phases.
Did SLA compliance worsen significantly in the crisis period? 
==============================================================*/ 
with orders as (select *,CASE WHEN ORDER_TIMESTAMP <'2025-06-01' AND ORDER_TIMESTAMP >='2025-01-01' THEN 'Pre-Crisis' WHEN ORDER_TIMESTAMP >='2025-06-01' AND ORDER_TIMESTAMP <'2025-10-01' THEN 'Crisis' END AS 'PHASE' from orders),
order_delivery as (select o.order_id,dp.actual_delivery_time_mins,dp.expected_delivery_time_mins,o.phase,case when dp.actual_delivery_time_mins <= dp.expected_delivery_time_mins then 1 else 0 end as is_compliant 
from delivery_performance dp inner join orders o on o.order_id = dp.order_id where o.phase is not null)
select phase,avg(actual_delivery_time_mins) as actual_time, avg(expected_delivery_time_mins) as expected_time,avg(actual_delivery_time_mins)-avg(expected_delivery_time_mins) as avg_delay,
concat(ROUND(sum(is_compliant)*100/count(*),2),'%') AS sla_compliance from order_delivery group by phase;
# In Crisis: Delays increased by 8.7x while customer fulfillment promises dropped by 31.32%.

/*==============================================================
Q6. Ratings Fluctuation: 
Track average customer rating month-by-month. 
Which months saw the sharpest drop?
==============================================================*/
with orders as (select *,CASE WHEN ORDER_TIMESTAMP <'2025-06-01' AND ORDER_TIMESTAMP >='2025-01-01' THEN 'Pre-Crisis' WHEN ORDER_TIMESTAMP >='2025-06-01' AND ORDER_TIMESTAMP <'2025-10-01' THEN 'Crisis' END AS 'PHASE' from orders),
order_rating as (select o.order_id,r.rating,monthname(o.order_timestamp) as month,o.phase from ratings r inner join orders o on r.order_id = o.order_id)
select month,phase,round(avg(rating),2) as avg_rating from order_rating group by month,phase order by avg(rating) asc;

/*==============================================================
Q7. Sentiment Insights: 
During the crisis period, identify the most frequently occurring negative keywords in customer review texts. 
(Hint: Use a Word Cloud visual in Power BI to visualize the findings.) 
==============================================================*/
select o.order_id,r.rating,r.review_text from ratings r inner join orders o on r.order_id = o.order_id
where o.order_timestamp >= '2025-06-01' and o.order_timestamp < '2025-10-01' and r.rating <= 3 and r.review_text is not null;

/*==============================================================
Q8. Revenue Impact: 
Estimate revenue loss from pre-crisis vs crisis (based on subtotal, discount, and delivery fee).
==============================================================*/
with orders as (select *,CASE WHEN ORDER_TIMESTAMP <'2025-06-01' AND ORDER_TIMESTAMP >='2025-01-01' THEN 'Pre-Crisis' WHEN ORDER_TIMESTAMP >='2025-06-01' AND ORDER_TIMESTAMP <'2025-10-01' THEN 'Crisis' END AS 'PHASE',(subtotal_amount+delivery_fee)-discount_amount as order_revenue from orders where lower(is_cancelled)='n'),
aggregated as (select phase,round(sum(discount_amount),2) as Total_discount,round(sum(order_revenue),2) as Total_Revenue from orders where phase is not null group by phase ),
revenue as (select (select total_revenue from aggregated where phase = 'pre-crisis') as estimated_revenue,(select total_revenue from aggregated where phase = 'crisis') as actual_revenue)
select *,estimated_revenue-actual_revenue as revenue_loss,round(((estimated_revenue-actual_revenue)*100/estimated_revenue),2) as revenue_decline from revenue;

/*==============================================================
Q9.
Loyalty Impact: 
Among customers who placed five or more orders before the 
crisis, determine how many stopped ordering during the crisis, and out of those, 
how many had an average rating above 4.5? 
==============================================================*/
with orders as (select *,CASE WHEN ORDER_TIMESTAMP <'2025-06-01' AND ORDER_TIMESTAMP >='2025-01-01' THEN 'Pre-Crisis' WHEN ORDER_TIMESTAMP >='2025-06-01' AND ORDER_TIMESTAMP <'2025-10-01' THEN 'Crisis' END AS 'PHASE' from orders),
orders_rating as (select o.customer_id,o.order_id,CASE WHEN ORDER_TIMESTAMP <'2025-06-01' AND ORDER_TIMESTAMP >='2025-01-01' THEN 'Pre-Crisis' WHEN ORDER_TIMESTAMP >='2025-06-01' AND ORDER_TIMESTAMP <'2025-10-01' THEN 'Crisis' END AS 'PHASE',r.rating from orders o inner join ratings r on o.order_id = r.order_id),
aggregated as (select customer_id,count(order_id) from orders where phase is not null and lower(phase) ='pre-crisis' group by customer_id having count(order_id) >=5 order by count(order_id) desc),
aggregated_rating_pre_crisis as (select customer_id, avg(rating) as avg_rating from orders_rating where phase is not null and lower(phase) ='pre-crisis' group by customer_id  having avg(rating) >= 4.5),
aggregated_rating_crisis as (select customer_id,avg(rating) from orders_rating where phase is not null and lower(phase) ='crisis' group by customer_id having avg(rating)>=4.5 order by count(order_id) desc),
lost as (select count(customer_id) as customer_lost,(select count(customer_id) from aggregated) as Pre_Crisis_customers from aggregated where customer_id not in (select customer_id from orders where lower(phase) = 'crisis'))
select customer_lost,pre_crisis_customers,(select count(*) from aggregated_rating_pre_crisis where customer_id in (select customer_id from (select customer_id from aggregated where customer_id not in (select customer_id from orders where lower(phase) = 'crisis')) as t)) as 'Rating >= 4.5 (Pre-Crisis)',
(select count(customer_id) from aggregated_rating_crisis where customer_id in (select customer_id from lost)) as 'Rating >=4.5 (Crisis)' from lost;

/*==============================================================
Q10. Customer Lifetime Decline: 
Which high-value customers (top 5% by total 
spend before the crisis) showed the largest drop in order frequency and ratings 
during the crisis? What common patterns (e.g., location, cuisine preference, 
delivery delays) do they share?
==============================================================*/
with orders as (select *,CASE WHEN ORDER_TIMESTAMP <'2025-06-01' AND ORDER_TIMESTAMP >='2025-01-01' THEN 'Pre-Crisis' WHEN ORDER_TIMESTAMP >='2025-06-01' AND ORDER_TIMESTAMP <'2025-10-01' THEN 'Crisis' END AS 'PHASE' from orders),
five_pct_filter as (select customer_id from (select customer_id,round(sum(total_amount),2) as Total_spending from orders  where lower(phase) = 'pre-crisis' group by customer_id order by sum(total_amount) desc limit 4187) t), -- (0.05*83740 = 4187) where total customer is 83740 in before crisis
aggregated_pre_crisis as (select o.customer_id,sum(o.total_amount) as Total_Spending_Pre_Crisis,count(o.order_id)/5 as Monthly_freq_Pre_Crisis,avg(cast(r.rating as float)) as Avg_Rating_Pre_Crisis from orders o left join ratings r on o.order_id=r.order_id where lower(phase) = 'pre-crisis' and o.customer_id in (select * from (five_pct_filter)) group by o.customer_id),
aggregated_crisis as (select o.customer_id,sum(o.total_amount) as Total_Spending_Crisis,count(o.order_id)/4 as Monthly_freq_Crisis,avg(cast(r.rating as float)) as Avg_Rating_Crisis from orders o left join ratings r on o.order_id=r.order_id where lower(phase)= 'crisis' and o.customer_id in (select * from (five_pct_filter)) group by o.customer_id),
aggregated_cuisine_pref as (select customer_id, cuisine_type from(select o.customer_id,rest.cuisine_type,row_number() over (partition by o.customer_id order by count(*) desc) as rn from orders o left join restaurant rest on o.restaurant_id = rest.restaurant_id where o.customer_id in (select * from (five_pct_filter)) and lower(o.phase) = 'pre-crisis' group by o.customer_id,rest.cuisine_type) t where rn = 1),
aggregated_cuisine_pref_crisis as (select customer_id, cuisine_type from (select o.customer_id,rest.cuisine_type,count(o.order_id) as total_orders,row_number() over (partition by o.customer_id order by count(o.order_id) desc) as rn from orders o left join restaurant rest on o.restaurant_id = rest.restaurant_id where o.customer_id in (select customer_id from five_pct_filter) and lower(o.phase)='crisis' group by o.customer_id, rest.cuisine_type) t where rn=1)
select pc.customer_id,cus.city,coalesce(acp.cuisine_type,'No orders') as 'Cuisine Preference (Pre-Crisis)',coalesce(acpc.cuisine_type,'No orders') as 'Cuisine Preference (Crisis)',round(coalesce(pc.Total_Spending_Pre_Crisis,0),2) as 'Total Spending (Pre-Crisis)',round(coalesce(c.Total_Spending_Crisis,0),2) as 'Total Spending (Crisis)',round(coalesce(pc.Monthly_freq_Pre_Crisis,0),2) as 'Monthly freq (Pre-Crisis)',round(coalesce(c.Monthly_freq_Crisis,0),2) as 'Monthly freq (Crisis)',
(coalesce(pc.Monthly_freq_Pre_Crisis,0)-coalesce(c.Monthly_freq_Crisis,0)) as monthly_freq_drop,
round(coalesce(pc.Avg_Rating_Pre_Crisis,0),2) as 'Avg Rating (Pre-Crisis)',round(coalesce(c.Avg_Rating_Crisis,0),2) as 'Avg Rating (Crisis)',
(coalesce(pc.Avg_Rating_Pre_Crisis,0)-coalesce(c.Avg_Rating_Crisis,0)) as rating_drop
from aggregated_pre_crisis pc left join aggregated_crisis c on pc.customer_id=c.customer_id left join customer cu on pc.customer_id=cu.customer_id 
left join customer cus on pc.customer_id=cus.customer_id left join aggregated_cuisine_pref acp on pc.customer_id = acp.customer_id left join aggregated_cuisine_pref_crisis acpc on pc.customer_id=acpc.customer_id order by monthly_freq_drop desc, rating_drop desc ;


/*==============================================================
                    SECONDARY ANALYSIS
==============================================================
Note:
Some business questions require additional datasets
(e.g., marketing spend, campaign performance,
customer acquisition channels, restaurant contracts,
or external competitor data).

Where sufficient data is unavailable, observations
are based only on the provided QuickBite datasets,
and limitations are explicitly documented.
==============================================================*/