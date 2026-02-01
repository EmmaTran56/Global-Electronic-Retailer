--q1--
SELECT 
	year(s.order_date) as year_order,
	month(s.order_date) as month_order,
	sum((p.unit_price_USD - p.unit_cost_USD)* s.Quantity) as total_profit
from products p
join sales s on p.productkey = s.productkey
group by year(s.order_date), month(s.order_date)
order by year_order, month_order

--q2--
with age as (
	Select 
		datediff(year,s.Birthday,getdate()) as age,
		Gender,
		Country,
		State
	from Customers s
),
age_group as (
	Select *,
		CASE 
			WHEN age <= 17 THEN '0-17'
			WHEN age between 18 and 25 THEN '18-25'
			WHEN age between 26 and 35 THEN '26-35'
			WHEN age between 36 and 45 THEN '36-45'
			WHEN age between 46 and 55 THEN '46-55'
			ELSE '56+'
		END AS AgeGroup
	from age
)
select 
	AgeGroup,
	Gender,
	Country,
	State,
	Count(*) as CustomerCount
from age_group
group by AgeGroup, Gender,Country,State
order by AgeGroup DESC

--3--
with t1 as (
	select 
		year(s.order_date) as Year_order,
		month(s.order_date) as Month_order, 
		sum((p.unit_price_USD - p.unit_cost_USD)* s.Quantity) as total_profit
	from sales s
	join Products p on s.ProductKey = p.ProductKey
	group by year(s.order_date), month(s.order_date)
),
t2 as (
	select 
		t1.Year_order,
		t1.Month_order,
		sum(t1.total_profit) over (order by t1.Year_order, Month_order) as cumulative_sale
	from t1
),
t3 as(
	select *,
		(t2.cumulative_sale-lag(t2.cumulative_sale) over(order by t2.Year_order, t2.Month_order))/(lag(t2.cumulative_sale) over(order by t2.Year_order, t2.Month_order)) *100 AS sale_diff
	from t2
)
Select *
from t3
where t3.sale_diff >=10
		
--q4--
with subcategorypairs as (
	select pa.Subcategory as subcategory_1,
		pb.Subcategory as subcategory_2,
		count(*) as count_pair
	from sales a
	join sales b on a.Order_Number = b.Order_Number
		and a.ProductKey < b. ProductKey
	join Products pa on a.ProductKey = pa.ProductKey
	join Products pb on b.ProductKey = pb.ProductKey
		and pa.Subcategory < pb.Subcategory
	group by pa.Subcategory, pb.Subcategory
)
select *,
	rank() over (order by count_pair desc) as rank_pair
from subcategorypairs
order by count_pair desc

--q5--
with product_qty as (
	select p.Category, c.Country, p.Product_Name, sum(s.Quantity) as total_quantity
	from sales s
	join products p on p.ProductKey = s.ProductKey
	join Customers c on c.CustomerKey = s.CustomerKey
	group by p.Category, c.Country, p.Product_Name
), 
ranked as(
	select Category, Country, Product_Name,
	dense_rank() over(partition by category, country order by total_quantity desc) as rank_product
	from product_qty
)
select *
from ranked 
where rank_product <=2

--q6--
with profit as(
	select st.StoreKey, st.Country, st.State, st.Square_Meters, sum(s.quantity * (p.unit_price_USD - p.unit_cost_USD)*ex.exchange) as totalprofitlocalcurrency
	from sales s
	join stores st on s.StoreKey = st.StoreKey
	join Products p on s.ProductKey = p.ProductKey
	join Exchange_Rates ex on s.Currency_Code = ex.Currency and s.Order_Date = ex.Date
	group by st.StoreKey, st.Country, st.State, st.Square_Meters
),
rank as (
	select 
		Storekey, Country, State, Square_Meters, totalprofitlocalcurrency,
		totalprofitlocalcurrency/Square_Meters as profitpersquaremeter,
		rank() over (order by totalprofitlocalcurrency/Square_Meters desc) as ranking
	from profit
)
select * from rank

--q8--
Declare @TargetOrderDate DATE = '2016-01-01'
select c.CustomerKey, c.Name, c.City, c.State, c.Country,
	count(s.order_number) as total_orders,
	sum(s.quantity) as total_quantity,
	min(s.order_date) as first_order_date,
	max(s.delivery_date) as last_delivery_date, 
	s.Order_Date
from Customers c
join sales s on c.CustomerKey = s.CustomerKey
Where s.Order_Date = @TargetOrderDate
group by c.CustomerKey, c.Name, c.City, c.State, c.Country, s.Order_Date
order by total_quantity desc

--q9--
declare @sql NVARCHAR(MAX);
declare @cols NVARCHAR(MAX);

--Build dynamic list of years
with distinctyear as(
	SELECT DISTINCT YEAR(order_date) as OrderYear
	From sales
)
select @cols = STRING_AGG(CONCAT('[', OrderYear, ']'), ',')
from distinctyear

--cols = [2021],[2022],...

set @sql = '
with sourcetable as (
SELECT 
	c.country,
	year(s.order_date) as OrderYear,
	count(distinct s.Order_Number) as totalorders
from sales s
join Customers c on s.CustomerKey = c.CustomerKey
where s.Order_Date is not null
group by c.country, year(s.order_date)
)
select
	country,
	' + @cols +'
from sourcetable
PIVOT (
	Sum(totalorders)
	for OrderYear IN (' +@cols + ')
) AS p
Order by country;
'
EXECUTE (@sql);