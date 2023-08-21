/*
US shipping data exploration

Skills used: Joins, CTE's, Temp Tables, Windows Functions, Aggregate Functions, Creating Views, Converting Data Types

*/

SELECT [Product Name] ,[Unit Price], [Shipping Cost], [Product Category], [Product Sub-Category], [Product Container] 
from Orders$

-- Looking at the costs to produce

/*
Base Margin = ((Selling Price - Cost of Products) / Selling Price)

Cost Price = Selling Price - (Selling Price * Base Margin)
*/

select
[Product Name],
[Unit Price],
([Unit Price] - ([Unit Price] * [Product Base Margin])) as 'Production Costs'
from Orders$

/*
Shown as a percentage
*/

With cte_productionCost as (
select
	[Product Name],
	[Unit Price],
	([Unit Price] - ([Unit Price] * [Product Base Margin])) as 'Production Costs'
from Orders$
)
select 
	cte_productionCost.[Product Name],
	cte_productionCost.[Production Costs],
	cte_productionCost.[Unit Price],
	(cte_productionCost.[Production Costs]/ cte_productionCost.[Unit Price]) * 100 as 'Cost to Sale %'
from cte_productionCost

/*
Compare the average cost to sale % of the three categories. Make a temp table first
*/
drop table if exists #temp_costs
create table #temp_costs (
name varchar(225),
Production_costs float,
Unit_price float,
Category varchar(225),
Sub_Category varchar(225),
Costs_To_Sale int
)

insert into #temp_costs
select 
	[Product Name],
	([Unit Price] - ([Unit Price] * [Product Base Margin])) as 'Production Costs',
	[Unit Price],
	[Product Category],
	[Product Sub-Category],
	null
from Orders$

update #temp_costs 
set #temp_costs.Costs_To_Sale = (Production_costs/Unit_price)*100

select * from #temp_costs where Category = 'Furniture'
select Category, AVG(Costs_To_Sale)
from #temp_costs
group by Category

/*
Looking at location (all are within US)
Create a temp table based on the columns needed
*/
drop table if exists #temp_locations
create table #temp_locations 
(
 [Product Name] varchar(225),
 Region varchar(225),
 [State] varchar(225),
 [Shipping Costs] float,
 [Ship Mode] varchar(225),
 [Size Parcel] varchar(225),
 [Quant Ordered New] int
)

insert into #temp_locations 
select [Product Name], Region, [State or Province], [Shipping Cost], [Ship Mode], [Product Container], [Quantity ordered new]
from Orders$

select *
from #temp_locations
where State = 'Alabama'

-- Region has the highest volume of orders

select State, sum([Quant Ordered New]) as 'Items Ordered'
from #temp_locations
group by state
order by [Items Ordered] desc

-- Looking at East and West regions only

select State, sum([Quant Ordered New]) as 'Items Ordered'
from #temp_locations
where Region like '%st%'
group by state
order by 2 desc

-- How many items were ordered by the East/West vs Central/South

select (
	select (sum([Quant Ordered New])) from #temp_locations where Region like '%st%' 
) as 'East and West', (
	select (sum([Quant Ordered New])) from #temp_locations where Region = 'South' or Region = 'Central'
)as 'South and Central'

-- partition by to see the costs and ship mode with regions

select [Product Name], Region, State, [Ship Mode], [Shipping Costs], 
	count(Region) OVER (partition by Region) as 'From Same Region'
from #temp_locations
order by [Shipping Costs] desc 

/*
Converting data
*/

-- find the max and min profit of items in each state, converted to the nearest whole dollar

select [State or Province], CEILING(MAX(Profit)) as 'Highest Profit Item/ $', CAST(MIN(Profit) as int) as 'Lowest Profit Item/ $'
from Orders$
group by [State or Province]
order by 2 desc

/*
Joining to the return table, see what items returned, who and what category
*/
select order_table.[Customer Name], order_table.[Product Name], order_table.[Product Sub-Category], order_table.[State or Province], return_table.[Order ID]
, Count(order_table.[State or Province]) over (partition by order_table.[State or Province]) as 'State Count'
from Orders$ as order_table
join Returns$ as return_table
	on order_table.[Order ID] = return_table.[Order ID]
where order_table.[Order ID] = return_table.[Order ID]
order by [Order ID]

/*
Views to store data for later visuals
*/

create view  shippingData as 
select order_table.[Customer Name], order_table.[Product Name], order_table.[Product Sub-Category], order_table.[State or Province], return_table.[Order ID]
, Count(order_table.[State or Province]) over (partition by order_table.[State or Province]) as 'State Count'
from Orders$ as order_table
join Returns$ as return_table
	on order_table.[Order ID] = return_table.[Order ID]
where order_table.[Order ID] = return_table.[Order ID]

create view maxMinTable as
select [State or Province], CEILING(MAX(Profit)) as 'Highest Profit Item/ $', CAST(MIN(Profit) as int) as 'Lowest Profit Item/ $'
from Orders$
group by [State or Province]

create view shippingCosts as
select [Product Name], Region, [State or Province], [Ship Mode], [Shipping Cost], 
	count(Region) OVER (partition by Region) as 'From Same Region'
from Orders$

create view regionSplit as
select (
	select (sum([Quantity ordered new])) from Orders$ where Region like '%st%' 
) as 'East and West', (
	select (sum([Quantity ordered new])) from Orders$ where Region = 'South' or Region = 'Central'
)as 'South and Central'

-- testing the view loads in
select *
from shippingData
