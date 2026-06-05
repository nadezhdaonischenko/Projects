/* Проект Анализ поведения игроков и внутриигровых транзакций
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты, а также оценить 
 * активность игроков при совершении внутриигровых покупок
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:

WITH new AS (
SELECT COUNT(DISTINCT id) AS total_users -- все игроки, 
       (SELECT COUNT(DISTINCT id) FROM fantasy.users WHERE payer = 1) AS paid_users --игроки покупающие внутриигровую валюту
FROM fantasy.users)

SELECT total_users, paid_users, ROUND(paid_users::numeric/total_users,4) AS dolya_paid_users
FROM new;

total_users|paid_users|dolya_paid_users|
-----------+----------+----------------+
      22214|      3929|          0.1769|
   
/*второй вариант расчета
SELECT COUNT(payer) AS total_payer,
       SUM(payer) AS paid_users,
       ROUND(AVG(payer),4) AS dolya_paid_users
FROM fantasy.users
WHERE payer = 0 OR payer = 1;*/
      
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
      
WITH total AS (
SELECT COUNT(DISTINCT id) AS total_users, race
FROM fantasy.users
JOIN fantasy.race USING(race_id)
GROUP BY race),

paid AS (
SELECT COUNT(DISTINCT id) AS paid_users, race
FROM fantasy.users
JOIN fantasy.race USING(race_id)
WHERE payer = 1
GROUP BY race)

SELECT race, total_users, paid_users, 
       ROUND(paid_users/total_users::NUMERIC,4) AS dolya_paid_users
FROM total
FULL JOIN paid USING(race)
ORDER BY paid_users;

race    |total_users|paid_users|dolya_paid_users|
--------+-----------+----------+----------------+
Angel   |       1327|       229|          0.1726|
Demon   |       1229|       238|          0.1937|
Elf     |       2501|       427|          0.1707|
Northman|       3562|       626|          0.1757|
Orc     |       3619|       636|          0.1757|
Hobbit  |       3648|       659|          0.1806|
Human   |       6328|      1114|          0.1760|

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:

SELECT COUNT(amount) AS total_count_amount --общее количество покупок, 
       SUM(amount) AS sum_amount, 
       MIN(amount) AS min_amount, 
       MAX(amount) AS max_amount, 
       ROUND(AVG(amount::numeric),2) AS avg_amount, 
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS mediana_amount, 
       ROUND(STDDEV(amount::numeric),2) AS std_amount
FROM fantasy.events

total_count_amount|sum_amount|min_amount|max_amount|avg_amount|mediana_amount|std_amount|
------------------+----------+----------+----------+----------+--------------+----------+
           1307678| 686615040|       0.0|  486615.1|    525.69|         74.86|   2517.35|

-- 2.2: Аномальные нулевые покупки:
    
SELECT (SELECT COUNT(amount) FROM fantasy.events) AS total_amount,
       COUNT(amount) AS zero_amount, --покупки с нулевой стоимостью
       ROUND(COUNT(amount)::numeric/(SELECT COUNT(amount) FROM fantasy.events),4) AS dolya_zero_amount
FROM fantasy.events
WHERE amount = 0.0;

total_amount|zero_amount|dolya_zero_amount|
------------+-----------+-----------------+
     1307678|        907|           0.0007|
        
/* второй вариант расчета
SELECT COUNT(*) AS total_amount,
       COUNT(*) FILTER (WHERE amount = 0) AS zero_amount,
       ROUND(COUNT(*)FILTER (WHERE amount = 0)::numeric / COUNT(*), 6) AS dolya_zero_amount
FROM fantasy.events;*/
        
SELECT race, COUNT(amount) AS zero_amount,
       ROUND(COUNT(amount)::numeric/(SELECT COUNT(amount) FROM fantasy.events),6) AS dolya_zero_amount
FROM fantasy.events
FULL JOIN fantasy.users USING(id)
FULL JOIN fantasy.race USING(race_id)
WHERE amount = 0.0
GROUP BY race
ORDER BY zero_amount DESC;

race    |zero_amount|dolya_zero_amount|
--------+-----------+-----------------+
Elf     |        821|         0.000628|
Human   |         22|         0.000017|
Hobbit  |         19|         0.000015|
Northman|         16|         0.000012|
Angel   |         15|         0.000011|
Orc     |         14|         0.000011|
       
-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
        
WITH new AS ((
SELECT CASE WHEN payer=1 THEN 'paid_users'
       END AS users_group,
       COUNT(DISTINCT events.id) AS users_count, --совершившие покупки, и являющиеся покупателями внутриигровой валюты
       COUNT(events.amount) AS count_amount, 
       SUM(events.amount) AS sum_amount
FROM fantasy.events
LEFT JOIN fantasy.users USING(id)
WHERE payer = 1 AND amount <> 0.0
GROUP BY payer)
UNION
(SELECT CASE WHEN payer=0 THEN 'not_paid_users'
        END AS users_group,
        COUNT(DISTINCT events.id) AS users_count, --совершившие покупки, неплатящие
        COUNT(events.amount) AS count_amount, 
        SUM(events.amount) AS sum_amount
FROM fantasy.events
LEFT JOIN fantasy.users USING(id)
WHERE payer = 0 AND amount <> 0.0
GROUP BY payer))

(SELECT users_group,
        users_count, count_amount, ROUND(count_amount::numeric/users_count,2) AS dolya_user, 
        sum_amount, ROUND(sum_amount::numeric/users_count,2) AS dolya_user
FROM NEW
GROUP BY users_group, users_count, count_amount, sum_amount)
UNION
(SELECT 'total_users_amount' AS users_group,
        SUM(users_count), SUM(count_amount), 
        ROUND(SUM(count_amount)::numeric/SUM(users_count),2) AS dolya_user, 
        SUM(sum_amount), 
        ROUND(SUM(sum_amount)::numeric/SUM(users_count),2) AS dolya_user
FROM NEW)
ORDER BY users_count;

users_group       |users_count|count_amount|dolya_user|sum_amount|dolya_user|
------------------+-----------+------------+----------+----------+----------+
paid_users        |       2444|      199626|     81.68| 135563136|  55467.68|
not_paid_users    |      11348|     1107145|     97.56| 551404992|  48590.50|
total_users_amount|      13792|     1306771|     94.75| 686968128|  49809.16|
        
-- 2.4: Популярные эпические предметы:

WITH NEW AS (
SELECT game_items, COUNT(amount) AS count_game_items, --распределение покупок по эпическим предметам 
       ROUND(COUNT(amount)::numeric/(SELECT COUNT(amount) FROM fantasy.events WHERE amount <> 0),6) AS dolya_count,
       ROUND(COUNT(DISTINCT id)::numeric/(SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount <> 0),6) AS dolya_users_total     
FROM fantasy.events
FULL JOIN fantasy.items USING(item_code)
WHERE amount <> 0
GROUP BY game_items
ORDER BY count_game_items DESC)

SELECT *
FROM NEW;

game_items               |count_game_items|dolya_count|dolya_users_total|
-------------------------+----------------+-----------+-----------------+
Book of Legends          |         1004516|   0.768701|         0.884136|
Bag of Holding           |          271875|   0.208051|         0.867749|
Necklace of Wisdom       |           13828|   0.010582|         0.117967|
Gems of Insight          |            3833|   0.002933|         0.067140|
Treasure Map             |            3183|   0.002436|         0.059382|
Amulet of Protection     |            1078|   0.000825|         0.032265|
Silver Flask             |             795|   0.000608|         0.045896|
...

WITH avg_dolya AS (
SELECT ROUND(COUNT(DISTINCT id)::numeric/(SELECT COUNT(DISTINCT id) 
                                          FROM fantasy.events 
                                          LEFT JOIN fantasy.users USING(id) 
                                          WHERE amount <> 0 AND payer = 1),6) AS dolya_users_paid,
       ROUND(COUNT(DISTINCT id)::numeric/(SELECT COUNT(DISTINCT id) 
                                          FROM fantasy.events 
                                          LEFT JOIN fantasy.users USING(id) 
                                          WHERE amount <> 0 AND payer = 0),6) AS dolya_users_not_paid                             
FROM fantasy.events
FULL JOIN fantasy.items USING(item_code)
WHERE amount <> 0
GROUP BY game_items)

SELECT ROUND(avg(dolya_users_paid),3) AS avg_dolya_users_paid, 
       ROUND(avg(dolya_users_not_paid),3) AS avg_dolya_users_not_paid,
       ROUND(avg(dolya_users_paid)/avg(dolya_users_not_paid),3)
FROM avg_dolya;                                       
                                          
avg_dolya_users_paid|avg_dolya_users_not_paid|round|
--------------------+------------------------+-----+
               0.095|                   0.021|4.643|
                    
-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:

WITH a AS (
SELECT race, COUNT(DISTINCT id) AS total_users, --добавляя условия amount<>0 значения в total=user_amount
       users_amount, paid_users
FROM fantasy.race
LEFT JOIN fantasy.users USING(race_id)
LEFT JOIN (SELECT race_id, COUNT(DISTINCT events.id) AS users_amount --совершившие покупки
           FROM fantasy.race 
           LEFT JOIN fantasy.users USING(race_id)
           RIGHT JOIN fantasy.events USING(id)
           WHERE amount <> 0
           GROUP BY race_id) AS amount USING(race_id)
LEFT JOIN (SELECT race_id, COUNT(DISTINCT events.id) AS paid_users --совершившие покупки, платящие
           FROM fantasy.race 
           LEFT JOIN fantasy.users USING(race_id)
           RIGHT JOIN fantasy.events USING(id)
           WHERE payer = 1 AND amount <> 0           
           GROUP BY race_id) AS paid USING(race_id)        
GROUP BY race, users_amount, paid_users),

b AS (
SELECT race,
       COUNT(amount) AS count_amount,
       SUM(amount) AS sum_amount
FROM fantasy.race
LEFT JOIN fantasy.users USING(race_id)
LEFT JOIN fantasy.events USING (id)
WHERE amount <> 0.0
GROUP BY race)
          
SELECT race, total_users, users_amount,
       ROUND(users_amount::numeric/total_users,4) AS dolya_users_amount,
       ROUND(paid_users::numeric/users_amount,4) AS dolya_paid_users,
       ROUND(AVG(count_amount::numeric/users_amount),2) AS avg_count_amount,
       ROUND(AVG(sum_amount::numeric/count_amount),2) AS avg_amount,
       ROUND(AVG(sum_amount::numeric/users_amount),2) AS avg_sum_amount
FROM a
FULL JOIN b USING(race)
GROUP BY race, total_users, users_amount, paid_users
ORDER BY avg_count_amount DESC;

race    |total_users|users_amount|dolya_users_amount|dolya_paid_users|avg_count_amount|avg_amount|avg_sum_amount|
--------+-----------+------------+------------------+----------------+----------------+----------+--------------+
Human   |       6328|        3921|            0.6196|          0.1801|          121.40|    403.07|      48933.69|
Angel   |       1327|         820|            0.6179|          0.1671|          106.80|    455.64|      48664.63|
Hobbit  |       3648|        2266|            0.6212|          0.1770|           86.13|    552.91|      47621.80|
Northman|       3562|        2229|            0.6258|          0.1821|           82.10|    761.48|      62519.07|
Orc     |       3619|        2276|            0.6289|          0.1740|           81.74|    510.92|      41761.69|
Elf     |       2501|        1543|            0.6170|          0.1627|           78.79|    682.33|      53761.24|
Demon   |       1229|         737|            0.5997|          0.1995|           77.87|    529.02|      41194.44|

-- Задача 2: Частота покупок

WITH time_new AS (--перевод времени в формат date
SELECT *, to_date(date, '%YYYY%MM%DD')  
FROM fantasy.events),

plus_duration AS (--добаление столбца периода между покупками
SELECT *, to_date - LAG(to_date) OVER(PARTITION BY id ORDER BY to_date) AS duration 
FROM time_new),

next AS (--вывод нужных столбцов и условий
SELECT plus_duration.id AS users, payer, COUNT(amount) AS count_amount,
       ROUND(AVG(duration::numeric),2) AS avg_duration
FROM plus_duration
LEFT JOIN fantasy.users USING(id)
WHERE amount <> 0.0
GROUP BY users, payer
HAVING COUNT(amount) >= 25),

finish AS (--ранжирование таблицы
SELECT *, NTILE(3) OVER(ORDER BY avg_duration) AS group_duration
FROM NEXT),

paid AS (SELECT COUNT(DISTINCT users) AS paid_users, group_duration--подсчет платящих игроков
           FROM finish 
           WHERE payer = 1 
           GROUP BY group_duration)

SELECT CASE WHEN group_duration = 1 THEN 'высокая частота'
            WHEN group_duration = 2 THEN 'умеренная частота'
            WHEN group_duration = 3 THEN 'низкая частота'
            END AS rate,
       COUNT(DISTINCT users) AS total_users_amount, 
       paid_users AS paid_users,
       ROUND(paid_users/COUNT(DISTINCT users)::numeric,2) AS dolya,
       ROUND(AVG(count_amount::numeric),2) AS avg_count_amount_group,
       ROUND(AVG(avg_duration::numeric),2) AS avg_duration_group
FROM finish
LEFT JOIN paid USING(group_duration)
GROUP BY group_duration, paid_users
ORDER BY avg_duration_group;

rate             |total_users_amount|paid_users|dolya|avg_count_amount_group|avg_duration_group|
-----------------+------------------+----------+-----+----------------------+------------------+
высокая частота  |              2572|       471| 0.18|                390.66|              3.29|
умеренная частота|              2572|       451| 0.18|                 58.80|              7.54|
низкая частота   |              2572|       435| 0.17|                 33.64|             13.29|





