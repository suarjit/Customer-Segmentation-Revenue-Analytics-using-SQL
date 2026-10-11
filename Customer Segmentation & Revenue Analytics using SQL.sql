USE Chinook;

-- Q1. Who are the highest-spending customers?

SELECT
    c.CustomerId,
    CONCAT(c.FirstName, ' ', c.LastName) AS customer_name,
    c.Country,
    COUNT(i.InvoiceId) AS total_invoices,
    ROUND(SUM(i.Total), 2) AS total_spending
FROM Customer AS c
JOIN Invoice AS i
    ON c.CustomerId = i.CustomerId
GROUP BY
    c.CustomerId,
    c.FirstName,
    c.LastName,
    c.Country
ORDER BY total_spending DESC
LIMIT 10;

-- Q2. Who are the most frequent purchasers?

SELECT
    c.CustomerId,
    CONCAT(c.FirstName, ' ', c.LastName) AS customer_name,
    c.Country,
    COUNT(i.InvoiceId) AS purchase_count,
    ROUND(SUM(i.Total), 2) AS total_spending
FROM Customer AS c
JOIN Invoice AS i
    ON c.CustomerId = i.CustomerId
GROUP BY
    c.CustomerId,
    c.FirstName,
    c.LastName,
    c.Country
ORDER BY purchase_count DESC, total_spending DESC
LIMIT 10;

-- Q3. Which customers have not purchased recently?

WITH last_purchase AS (
    SELECT
        CustomerId,
        MAX(InvoiceDate) AS last_purchase_date
    FROM Invoice
    GROUP BY CustomerId
),
dataset_dates AS (
    SELECT MAX(InvoiceDate) AS latest_date
    FROM Invoice
)
SELECT
    c.CustomerId,
    CONCAT(c.FirstName, ' ', c.LastName) AS customer_name,
    lp.last_purchase_date,
    CASE
        WHEN lp.last_purchase_date IS NULL
            THEN 'Never purchased'
        ELSE 'Inactive for 6+ months'
    END AS customer_status
FROM Customer AS c
LEFT JOIN last_purchase AS lp
    ON c.CustomerId = lp.CustomerId
CROSS JOIN dataset_dates AS dd
WHERE lp.last_purchase_date IS NULL
   OR lp.last_purchase_date < DATE_SUB(
       dd.latest_date, INTERVAL 6 MONTH
   )
ORDER BY lp.last_purchase_date;

-- Q4. Which countries have the highest-value customers?

SELECT
    c.Country,
    COUNT(DISTINCT c.CustomerId) AS total_customers,
    ROUND(AVG(customer_totals.total_spending), 2)
        AS avg_customer_spending,
    ROUND(SUM(customer_totals.total_spending), 2)
        AS country_revenue
FROM Customer AS c
JOIN (
    SELECT
        CustomerId,
        SUM(Total) AS total_spending
    FROM Invoice
    GROUP BY CustomerId
) AS customer_totals
    ON c.CustomerId = customer_totals.CustomerId
GROUP BY c.Country
ORDER BY avg_customer_spending DESC;

-- Q5. What is the average customer lifetime spending?

WITH customer_spending AS (
    SELECT
        c.CustomerId,
        COALESCE(SUM(i.Total), 0) AS lifetime_spending
    FROM Customer AS c
    LEFT JOIN Invoice AS i
        ON c.CustomerId = i.CustomerId
    GROUP BY c.CustomerId
)
SELECT
    COUNT(*) AS total_customers,
    ROUND(AVG(lifetime_spending), 2)
        AS avg_lifetime_spending,
    ROUND(SUM(lifetime_spending), 2)
        AS total_revenue
FROM customer_spending;

-- Q6. Which music genres are most popular?

SELECT
    g.GenreId,
    g.Name AS genre_name,
    SUM(il.Quantity) AS tracks_purchased,
    COUNT(DISTINCT i.CustomerId) AS unique_customers,
    ROUND(
        SUM(il.UnitPrice * il.Quantity), 2
    ) AS revenue
FROM Genre AS g
JOIN Track AS t
    ON g.GenreId = t.GenreId
JOIN InvoiceLine AS il
    ON t.TrackId = il.TrackId
JOIN Invoice AS i
    ON il.InvoiceId = i.InvoiceId
GROUP BY g.GenreId, g.Name
ORDER BY tracks_purchased DESC;

-- Q7. Which artists generate the highest revenue?

SELECT
    ar.ArtistId,
    ar.Name AS artist_name,
    COUNT(DISTINCT i.InvoiceId) AS invoices,
    SUM(il.Quantity) AS tracks_sold,
    ROUND(
        SUM(il.UnitPrice * il.Quantity), 2
    ) AS revenue
FROM Artist AS ar
JOIN Album AS al
    ON ar.ArtistId = al.ArtistId
JOIN Track AS t
    ON al.AlbumId = t.AlbumId
JOIN InvoiceLine AS il
    ON t.TrackId = il.TrackId
JOIN Invoice AS i
    ON il.InvoiceId = i.InvoiceId
GROUP BY ar.ArtistId, ar.Name
ORDER BY revenue DESC
LIMIT 10;

-- Q8. Which tracks are purchased most frequently?

SELECT
    t.TrackId,
    t.Name AS track_name,
    ar.Name AS artist_name,
    SUM(il.Quantity) AS times_purchased,
    ROUND(
        SUM(il.UnitPrice * il.Quantity), 2
    ) AS revenue
FROM Track AS t
JOIN Album AS al
    ON t.AlbumId = al.AlbumId
JOIN Artist AS ar
    ON al.ArtistId = ar.ArtistId
JOIN InvoiceLine AS il
    ON t.TrackId = il.TrackId
GROUP BY
    t.TrackId,
    t.Name,
    ar.Name
ORDER BY times_purchased DESC, revenue DESC
LIMIT 10;

-- Q9. Create customer segments: High, Medium, and Low Value

WITH customer_spending AS (
    SELECT
        c.CustomerId,
        CONCAT(c.FirstName, ' ', c.LastName)
            AS customer_name,
        COALESCE(SUM(i.Total), 0) AS total_spending
    FROM Customer AS c
    LEFT JOIN Invoice AS i
        ON c.CustomerId = i.CustomerId
    GROUP BY
        c.CustomerId,
        c.FirstName,
        c.LastName
),
average_spending AS (
    SELECT AVG(total_spending) AS avg_spending
    FROM customer_spending
)
SELECT
    cs.CustomerId,
    cs.customer_name,
    ROUND(cs.total_spending, 2) AS total_spending,
    ROUND(a.avg_spending, 2) AS avg_spending,
    CASE
        WHEN cs.total_spending >= 2 * a.avg_spending
            THEN 'High Value'
        WHEN cs.total_spending >= a.avg_spending
            THEN 'Medium Value'
        ELSE 'Low Value'
    END AS customer_segment
FROM customer_spending AS cs
CROSS JOIN average_spending AS a
ORDER BY cs.total_spending DESC;

-- Q10. Rank customers by spending within each country

WITH customer_spending AS (
    SELECT
        c.CustomerId,
        CONCAT(c.FirstName, ' ', c.LastName)
            AS customer_name,
        c.Country,
        COALESCE(SUM(i.Total), 0) AS total_spending
    FROM Customer AS c
    LEFT JOIN Invoice AS i
        ON c.CustomerId = i.CustomerId
    GROUP BY
        c.CustomerId,
        c.FirstName,
        c.LastName,
        c.Country
)
SELECT
    CustomerId,
    customer_name,
    Country,
    ROUND(total_spending, 2) AS total_spending,
    DENSE_RANK() OVER (
        PARTITION BY Country
        ORDER BY total_spending DESC
    ) AS country_rank
FROM customer_spending
ORDER BY Country, country_rank;

-- Q11. Find customers whose spending is below average

WITH customer_spending AS (
    SELECT
        c.CustomerId,
        CONCAT(c.FirstName, ' ', c.LastName)
            AS customer_name,
        COALESCE(SUM(i.Total), 0) AS total_spending
    FROM Customer AS c
    LEFT JOIN Invoice AS i
        ON c.CustomerId = i.CustomerId
    GROUP BY
        c.CustomerId,
        c.FirstName,
        c.LastName
)
SELECT
    CustomerId,
    customer_name,
    ROUND(total_spending, 2) AS total_spending
FROM customer_spending
WHERE total_spending < (
    SELECT AVG(total_spending)
    FROM customer_spending
)
ORDER BY total_spending DESC;

-- Q12. Find the top three customers in each country

WITH customer_spending AS (
    SELECT
        c.CustomerId,
        CONCAT(c.FirstName, ' ', c.LastName)
            AS customer_name,
        c.Country,
        COALESCE(SUM(i.Total), 0) AS total_spending
    FROM Customer AS c
    LEFT JOIN Invoice AS i
        ON c.CustomerId = i.CustomerId
    GROUP BY
        c.CustomerId,
        c.FirstName,
        c.LastName,
        c.Country
),
ranked_customers AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY Country
            ORDER BY total_spending DESC, CustomerId
        ) AS row_num
    FROM customer_spending
)
SELECT
    CustomerId,
    customer_name,
    Country,
    ROUND(total_spending, 2) AS total_spending,
    row_num AS country_rank
FROM ranked_customers
WHERE row_num <= 3
ORDER BY Country, country_rank;

-- Q13. Identify customers who have purchased from multiple genres

SELECT
    c.CustomerId,
    CONCAT(c.FirstName, ' ', c.LastName)
        AS customer_name,
    COUNT(DISTINCT g.GenreId) AS genres_purchased,
    GROUP_CONCAT(
        DISTINCT g.Name
        ORDER BY g.Name
        SEPARATOR ', '
    ) AS genre_list,
    ROUND(SUM(il.UnitPrice * il.Quantity), 2)
        AS total_revenue
FROM Customer AS c
JOIN Invoice AS i
    ON c.CustomerId = i.CustomerId
JOIN InvoiceLine AS il
    ON i.InvoiceId = il.InvoiceId
JOIN Track AS t
    ON il.TrackId = t.TrackId
JOIN Genre AS g
    ON t.GenreId = g.GenreId
GROUP BY
    c.CustomerId,
    c.FirstName,
    c.LastName
HAVING COUNT(DISTINCT g.GenreId) > 1
ORDER BY genres_purchased DESC, total_revenue DESC;

-- Q14. Calculate each customer's percentage contribution to total revenue

WITH customer_revenue AS (
    SELECT
        c.CustomerId,
        CONCAT(c.FirstName, ' ', c.LastName)
            AS customer_name,
        COALESCE(SUM(i.Total), 0) AS total_spending
    FROM Customer AS c
    LEFT JOIN Invoice AS i
        ON c.CustomerId = i.CustomerId
    GROUP BY
        c.CustomerId,
        c.FirstName,
        c.LastName
)
SELECT
    CustomerId,
    customer_name,
    ROUND(total_spending, 2) AS total_spending,
    ROUND(
        100.0 * total_spending
        / NULLIF(SUM(total_spending) OVER (), 0),
        2
    ) AS revenue_percentage
FROM customer_revenue
ORDER BY revenue_percentage DESC;

-- Q15. Calculate cumulative revenue using a window function

WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(InvoiceDate, '%Y-%m')
            AS sales_month,
        SUM(Total) AS revenue
    FROM Invoice
    GROUP BY DATE_FORMAT(InvoiceDate, '%Y-%m')
)
SELECT
    sales_month,
    ROUND(revenue, 2) AS monthly_revenue,
    ROUND(
        SUM(revenue) OVER (
            ORDER BY sales_month
            ROWS BETWEEN UNBOUNDED PRECEDING
                     AND CURRENT ROW
        ),
        2
    ) AS cumulative_revenue
FROM monthly_revenue
ORDER BY sales_month;
