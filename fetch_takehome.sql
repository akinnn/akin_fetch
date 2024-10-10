use covid;

select * from user_takehome
limit 100;

select * from transaction_takehome
limit 100;

select * from products_takehome
limit 100;

-- FIRST: EXPLORE THE DATA

-- 1. Quality Issues

/*
	Summary
    
    user_takehome table:
    - Invalid birth dates (early 1900s)
    - No value rows in birth_date, state, language, gender columns.
    - Unclear value ('es-419') in the language column. 
    
    products_takehome table: 
    - No value rows in category columns, manufacturer, brand, barcode columns. 
    
    transaction_takehome table:
    - No value rows in barcode, final_sale columns. 
    - There are final sale amounts even though the final_quantity column is 'zero'
*/

-- no value rows in genders
select count(*) from user_takehome; -- 100000
select count(*) from user_takehome 
where gender ='';-- 5892

-- Unique genders and their counts
select distinct gender, count(*)
from user_takehome
group by gender
order by 2 desc;

-- There are 3 unique fields for language column. One of them has no value rows.
-- The other value is 'en' which I assume is English, the last value is 'es-419' which is not clearly defined. 
select distinct language, count(*)
from user_takehome
group by language
order by 2 desc;

-- There are birth dates that go back to early 1900s, those records are most likely invalid.
select distinct birth_date
from user_takehome
group by birth_date
order by 1 asc
limit 100;

-- 983 records have final sale amount even thought the final_quantity is 'zero'
select count(*)
from transaction_takehome
where final_quantity = 'zero' and final_sale is not null;

-- 2. Fields that are challenging to understand

/*
	Summary
    
    user_takehome table:
    -  language field needs to be more descriptive, especially for the value 'es-419'
    
    products_takehome table: 
    -  category_1, 2, 3, 4 column names are challenging to understand and should be more descriptive 
*/


-- SECOND: PROVIDE QUERIES

-- Close Ended Questions

-- 1. Top 5 brands by receipts scanned among users 21 and over

select p.brand
from products_takehome p
join transaction_takehome t on p.barcode = t.barcode
join user_takehome u on t.user_id = u.id
where timestampdiff(year, substring(birth_date, 1, 19), curdate()) >= 21
order by brand desc
limit 5; 

-- 2. Top 5 brands by sales among users that have had their account for at least six months

select p.brand
from products_takehome p
join transaction_takehome t on p.barcode = t.barcode
join user_takehome u on t.user_id = u.id
where substring(created_date, 1, 19) <= date_sub(curdate(), interval 6 month)
order by t.final_sale desc
limit 5; 

-- 3. Percentage of sales in the Health & Wellness category by generation?

select 
    case 
        when year(u.birth_date) between 1930 and 1964 then 'Baby Boomers'
        when year(u.birth_date) between 1965 and 1980 then 'Generation X'
        when year(u.birth_date) between 1981 and 1999 then 'Millennials'
        when year(u.birth_date) between 2000 and 2022 then 'Generation Z'
        else 'Other'
    end as generation,
    SUM(t.final_sale) as total_sales_per_generation,
    (SUM(t.final_sale) / (select SUM(t2.final_sale)
                    from transaction_takehome t2
                    join products_takehome p2 on t2.barcode = p2.barcode
                    where p2.category_1 = 'Health & Wellness')) * 100 as sales_percentage
from transaction_takehome t
join products_takehome p on t.barcode = p.barcode
join user_takehome u ON t.user_id = u.id
where p.category_1 = 'Health & Wellness'
group by generation;

-- Open Ended Questions

-- 1. Who are Fetch’s power users?
/*
	Assumptions
    1. Power user could be defined as a user who makes the most purchases and/or who spends the most money.
    2. I assume that power users are those that made at least 10 transactions or have spent more than $100. 
     - According to my assumption, there are no power users. Hence, I will make another assumption that:
		power users are those that made at least 2 transactions or have spent more than $10.
*/

-- Return a list of users who are considered power users based on transaction frequency or high total spending.
-- These 3 users are Fetch's power users: 5d191765c8b1ba28e74e8463, 64dd9170516348066e7c4006, 646bdaa67a342372c857b958	

select 
    u.id as user_id,
    COUNT(t.receipt_id) as total_transactions,
    SUM(t.final_sale) as total_sales
from user_takehome u
join transaction_takehome t on u.id = t.user_id
group by u.id
having COUNT(t.receipt_id) >= 2 or SUM(t.final_sale) >= 10
order by total_sales desc, total_transactions desc;

-- 2. Which is the leading brand in the Dips & Salsa category?
/*
	Assumptions
    1. I assume that the leading brand is defined as the brand with the highest total sales in the "Dips & Salsa" category.
    2. The products_takehome table contains a column category_2, which has the main product category value: "Dips & Salsa".
    3. I assume that the brand column in the products_takehome table indicates the brand of each product.
*/

-- Return the brand with the highest total sales in the "Dips & Salsa" category
-- The brand with the higest sales is a null value, hence, I will take the second brand as the leading brand which is 'TOSTITOS'

select 
	p.brand, 
	SUM(t.final_sale) as total_sales
from products_takehome p
join transaction_takehome t on p.barcode = t.barcode
where p.category_2 = 'Dips & Salsa'
group by p.brand
order by total_sales desc
limit 2;

-- 3. At what percent has Fetch grown year over year?
/*
	Assumptions
    1. I assume that growth is assumed to be based on total sales in the transaction_takehome table
    2. I assume year over year growth is defined by the percentage increase in total sales from one year to the next
    3. I will use the purchase_date column in the transaction_takehome table to return the year for each transaction.
*/

select 
    year(t.purchase_date) as year,
    SUM(t.final_sale) as total_sales,
    lag(SUM(t.final_sale)) over (order by year(t.purchase_date)) as previous_year_sales,
    ((SUM(t.final_sale) - lag(SUM(t.final_sale)) over (order by year(t.purchase_date))) / lag(SUM(t.final_sale)) over (order by year(t.purchase_date)) * 100) as growth_percentage
from transaction_takehome t
group by year(t.purchase_date)
order by year;


