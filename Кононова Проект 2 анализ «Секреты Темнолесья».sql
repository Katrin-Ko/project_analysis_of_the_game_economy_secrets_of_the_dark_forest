/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Кононова Екатерина Андреевна
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT COUNT (id) AS count_users, --общее количество игроков
SUM (payer) AS count_pay_users,-- количество платящих игроков
ROUND (AVG (payer),2) AS fraction_pay_users-- доля платящих игроков от общего кол-ва
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT  fr.race_id,
fr.race,
COUNT (fu.id) AS count_users, --общее кол-во игроков расы
SUM (fu.payer) AS count_pay_users, -- кол-во платящих игроков расы
ROUND(SUM(fu.payer)::numeric/ COUNT(fu.id),2) AS fraction_race_pay_users --доля платящих в разресе расы персонажа
FROM fantasy.users AS fu
LEFT JOIN fantasy.race AS fr ON fu.race_id= fr.race_id 
GROUP BY fr.race_id;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT (transaction_id) AS count_transaction,
SUM (amount ) AS sum_amount,
MIN (amount ) AS min_amount,
MAX (amount) AS max_amount,
ROUND (AVG (amount)::numeric,2) AS avg_amount,
ROUND (PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount)::NUMERIC,2) AS median_amount,
ROUND (STDDEV(amount)::NUMERIC,2) AS stddev_amount
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
SELECT SUM (CASE WHEN amount=0 THEN 1 ELSE 0 END) AS count_zero_amount, --кол-во нулевых покупок 
COUNT (*) AS count_total , -- общее число покупок 
ROUND (SUM(CASE WHEN amount=0 THEN 1 ELSE 0 END)::NUMERIC / COUNT (*) *100,2) AS fraction_zero_amount --доля нулевых покупок
FROM fantasy.events; 

-- 2.3: Популярные эпические предметы:
-- СТЕ исключаем нулевые покупки 
WITH valid_events AS (
SELECT *
FROM fantasy.events
WHERE amount > 0),
--СТЕ считаем кол-во продаж и игроков по каждому предмету
stats AS (
SELECT item_code,
COUNT(transaction_id) AS count_transaction,
COUNT(DISTINCT id) AS count_users
FROM valid_events
GROUP BY item_code),
--СТЕ считаем общее кол-во продаж и игроков
totals AS (
SELECT SUM(count_transaction) AS total_transaction,
(SELECT COUNT(DISTINCT id) FROM valid_events) AS total_users
FROM stats)
--Основной запрос 
--считаем доли и собираем итоговую таблицу
SELECT fi.game_items,
s.item_code ,
s.count_transaction,
ROUND((s.count_transaction::numeric / t.total_transaction * 100), 2) AS fraction_transaction,
ROUND((s.count_users::numeric / t.total_users * 100), 2) AS fraction_users
FROM stats AS s
CROSS JOIN totals AS t
LEFT JOIN fantasy.items AS fi ON s.item_code=fi.item_code 
ORDER BY fraction_users DESC;

-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
--CTE считаем общее кол-во игроков для каждой расы и кол-во платящих
WITH total_users AS (
SELECT race_id,
COUNT (id) AS count_users
FROM fantasy.users
GROUP BY race_id),
-- СТЕ фильтруем игроков с покупкой>0
users AS (
SELECT fu.race_id, 
fe.id ,
fu.payer
FROM fantasy.users AS fu 
LEFT JOIN fantasy.events AS fe ON fu.id=fe.id
WHERE fe.amount>0
GROUP BY fe.id, fu.race_id, fu.payer ),
-- CTE считаем кол-во игроков совершивших внутриигровую покупку, игроков платящих и их долю от игроков совершивших внутриигровую покупку
pay_users AS (
SELECT race_id,
COUNT(id) AS count_user,
SUM(payer) AS count_pay_users,
ROUND (SUM(payer)::NUMERIC/count(id)::NUMERIC*100,2) AS fraction_pay_users
FROM users
GROUP BY race_id),
--CTE собираем информацию об активности игроков совершивших внутриигровые покупки
stat_users AS (
SELECT fu.race_id,
fe.id AS user_id,
COUNT (fe.transaction_id) AS count_transaction,
SUM (fe.amount) AS sum_amount,
AVG (fe.amount) AS avg_amount
FROM fantasy.users AS fu 
LEFT JOIN fantasy.events AS fe ON fu.id=fe.id AND fe.amount>0
GROUP BY race_id, user_id ),
-- Основной запрос
total AS ( 
SELECT r.race,
tu.count_users,
pu.count_user,
ROUND(pu.count_user::NUMERIC/tu.count_users::NUMERIC*100,2) AS fraction_users,
pu.fraction_pay_users,
ROUND(AVG(su.count_transaction)::NUMERIC,2)AS avg_count_transaction,
ROUND(AVG(avg_amount)::NUMERIC,2) AS avg_amount,
ROUND(AVG(sum_amount)::NUMERIC,2) AS avg_sum_amount
FROM total_users AS tu
LEFT JOIN pay_users AS pu ON tu.race_id=pu.race_id 
LEFT JOIN stat_users AS su ON tu.race_id=su.race_id 
JOIN fantasy.race AS r ON tu.race_id=r.race_id 
GROUP BY r.race ,tu.count_users ,pu.count_user ,pu.fraction_pay_users)
--Основной запрос
SELECT race AS"Раса персонажа",
count_users AS "Всего игроков", 
count_user AS "Количество покупателей",
fraction_users AS "Доля покупателей",
fraction_pay_users AS "Доля платящих среди покупателей",
avg_count_transaction AS "Среднее число покупок на игрока",
avg_amount AS "Средняя стоимость покупки",
avg_sum_amount AS "Средняя сумма всех покупок на игрока"
FROM total
ORDER BY avg_amount DESC;
