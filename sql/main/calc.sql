CREATE TABLE bookings.results (
    id int,
    response text
);

-- 1.	Вывести максимальное количество человек в одном бронировании
INSERT INTO bookings.results (id, response)
SELECT 1 as id, count(passenger_id) as cnt_passenger_id
FROM bookings.tickets
GROUP BY book_ref
ORDER BY count(passenger_id) DESC
LIMIT 1;

-- 2.	Вывести количество бронирований с количеством людей больше среднего значения людей на одно бронирование
INSERT INTO bookings.results (id, response)
SELECT 2 as id, count(t.book_ref) as cnt_book_ref
FROM (
         SELECT book_ref
         FROM bookings.tickets
         GROUP BY book_ref
         HAVING COUNT(passenger_id) > (
                                          SELECT COUNT(passenger_id) / COUNT(DISTINCT book_ref) * 1.0
                                          FROM bookings.tickets
                                      )
     ) t;

-- 3.	Вывести количество бронирований, у которых состав пассажиров повторялся два и более раза, среди бронирований с максимальным количеством людей (п.1)?
INSERT INTO bookings.results (id, response)
SELECT 3 as id, count(tmp.book_ref)
FROM (
         SELECT book_ref
              , string_agg(passenger_id, ',' ORDER BY passenger_id) as passenger_group
              , rank() OVER (ORDER BY count(passenger_id) DESC) AS rnk
         FROM bookings.tickets
         GROUP BY book_ref
         ORDER BY count(passenger_id) DESC
     ) tmp
WHERE tmp.rnk = 1
GROUP BY tmp.passenger_group
HAVING count(tmp.passenger_group) > 1;


-- 4.	Вывести номера брони и контактную информацию по пассажирам в брони (passenger_id, passenger_name, contact_data) с количеством людей в брони = 3
INSERT INTO bookings.results (id, response)
SELECT 4 as id, concat_ws('|', passenger_id, passenger_name, contact_data ) as passenger_info
FROM bookings.tickets
WHERE book_ref IN (
                      SELECT book_ref
                      FROM bookings.tickets
                      GROUP BY book_ref
                      HAVING COUNT(passenger_id) = 3
                  )
ORDER BY passenger_info;


-- 5.	Вывести максимальное количество перелётов на бронь
INSERT INTO bookings.results (id, response)
SELECT 5 AS id, COUNT(flight_id) AS cnt_flight_id
FROM bookings.tickets t
    JOIN bookings.ticket_flights tf ON t.ticket_no = tf.ticket_no
GROUP BY t.book_ref
ORDER BY cnt_flight_id DESC
LIMIT 1;


-- 6.	Вывести максимальное количество перелётов на пассажира в одной брони
INSERT INTO bookings.results (id, response)
SELECT 6 AS id, COUNT(tf.flight_id) AS cnt_flight_id
FROM bookings.tickets t
    JOIN bookings.ticket_flights tf ON t.ticket_no = tf.ticket_no
GROUP BY t.book_ref, passenger_id
ORDER BY cnt_flight_id DESC
LIMIT 1;


-- 7.	Вывести максимальное количество перелётов на пассажира
INSERT INTO bookings.results (id, response)
SELECT 7 AS id, COUNT(tf.flight_id) AS cnt_flight_id
FROM bookings.tickets t
    JOIN bookings.ticket_flights tf ON t.ticket_no = tf.ticket_no
GROUP BY passenger_id
ORDER BY cnt_flight_id DESC
LIMIT 1;


-- 8.	Вывести контактную информацию по пассажиру(ам) (passenger_id, passenger_name, contact_data) и общие траты на билеты, для пассажира потратившему минимальное количество денег на перелеты
INSERT INTO bookings.results (id, response)
SELECT 8 as id, concat_ws('|', tmp.passenger_id, tmp.passenger_name, tmp.contact_data, tmp.sum_amount)  as passenger_info
FROM (
         SELECT t.passenger_id
              , t.passenger_name
              , t.contact_data
              , SUM(tf.amount) AS sum_amount
              , RANK() OVER (ORDER BY SUM(tf.amount)) as rnk
         FROM bookings.tickets t
             JOIN bookings.ticket_flights tf ON t.ticket_no = tf.ticket_no
             JOIN bookings.flights f ON tf.flight_id = f.flight_id
         WHERE f.status != 'Cancelled'
         GROUP BY t.passenger_id, t.passenger_name, t.contact_data
         ORDER BY SUM(tf.amount)
     ) tmp
WHERE tmp.rnk = 1
ORDER BY passenger_info;


-- 9.	Вывести контактную информацию по пассажиру(ам) (passenger_id, passenger_name, contact_data) и общее время в полётах, для пассажира, который провёл максимальное время в полётах
INSERT INTO bookings.results (id, response)
SELECT 9 as id, concat_ws('|', tmp.passenger_id, tmp.passenger_name, tmp.contact_data, tmp.sum_actual_duration)  as passenger_info
FROM (
         SELECT t.passenger_id
              , t.passenger_name
              , t.contact_data
              , SUM(f.actual_duration) AS sum_actual_duration
              , RANK() OVER (ORDER BY SUM(f.actual_duration) DESC) as rnk
         FROM bookings.tickets t
             JOIN bookings.ticket_flights tf ON t.ticket_no = tf.ticket_no
             JOIN bookings.flights_v f ON tf.flight_id = f.flight_id
         WHERE f.status = 'Arrived'
         GROUP BY t.passenger_id, t.passenger_name, t.contact_data
         ORDER BY sum_actual_duration DESC
     ) tmp
WHERE tmp.rnk = 1
ORDER BY passenger_info;


-- 10.	Вывести город(а) с количеством аэропортов больше одного
INSERT INTO bookings.results (id, response)
SELECT 10 as id, city
FROM bookings.airports
GROUP BY city
HAVING count(airport_code) > 1
ORDER BY city;


-- 11.	Вывести город(а), у которого самое меньшее количество городов прямого сообщения
INSERT INTO bookings.results (id, response)
SELECT 11 as id, tmp.departure_city
FROM (
         SELECT COUNT(DISTINCT arrival_city)                        AS cnt_arrival_city
              , departure_city
              , RANK() OVER (ORDER BY COUNT(DISTINCT arrival_city)) AS rnk
         FROM bookings.routes
         GROUP BY departure_city
         ORDER BY cnt_arrival_city
     ) tmp
WHERE tmp.rnk = 1
ORDER BY tmp.departure_city;


-- 12.	Вывести пары городов, у которых нет прямых сообщений исключив реверсные дубликаты
INSERT INTO bookings.results (id, response)
SELECT 12 as id, concat(t.departure_city, '|', t.arrival_city) as pair_city
FROM (   -- Все возможные вариации связей городов с друг другом
         SELECT dep.city AS departure_city
              , arr.city AS arrival_city
         FROM bookings.airports dep
            , bookings.airports arr
         WHERE dep.city != Arr.city -- города с одинаковыми наименованиями не связываем
         EXCEPT
         -- все существующие прямые рейсы между городами
         SELECT dep.city AS departure_city
              , arr.city AS arrival_city
         FROM bookings.flights f
            , bookings.airports dep
            , bookings.airports arr
         WHERE f.departure_airport = dep.airport_code
           AND f.arrival_airport = arr.airport_code
     ) t
WHERE departure_city < arrival_city
ORDER BY pair_city;


-- 13.	Вывести города, до которых нельзя добраться без пересадок из Москвы
INSERT INTO bookings.results (id, response)
SELECT 13 as id, city
FROM airports
WHERE city != 'Москва'
  AND city NOT IN (
                      SELECT arrival_city
                      FROM bookings.routes
                      WHERE departure_city = 'Москва'
                  )
ORDER BY city;


-- 14.	Вывести модель самолета, который выполнил больше всего рейсов
INSERT INTO bookings.results (id, response)
SELECT 14 as id, a.model
FROM bookings.flights f
    JOIN bookings.aircrafts a ON f.aircraft_code = a.aircraft_code
WHERE f.status = 'Arrived'
GROUP BY a.model
ORDER BY count(flight_id) DESC
LIMIT 1;


-- 15.	Вывести модель самолета, который перевез больше всего пассажиров
INSERT INTO bookings.results (id, response)
SELECT 15 as id, a.model
FROM bookings.ticket_flights tf
    JOIN bookings.flights f ON tf.flight_id = f.flight_id
    JOIN aircrafts a ON f.aircraft_code = a.aircraft_code
WHERE f.status = 'Arrived'
GROUP BY a.model
ORDER BY count(tf.ticket_no) DESC
LIMIT 1;


-- 16.	Вывести отклонение в минутах суммы запланированного времени перелета от фактического по всем перелётам
INSERT INTO bookings.results (id, response)
SELECT 16 as id, abs(extract(epoch from sum(scheduled_duration) - sum(actual_duration)) / 60)::int as difference
FROM bookings.flights_v
WHERE status = 'Arrived';


-- 17.	Вывести города, в которые осуществлялся перелёт из Санкт-Петербурга 2016-09-13
INSERT INTO bookings.results (id, response)
SELECT 17 as id, arrival_city
FROM bookings.flights_v
WHERE actual_departure::date = '2016-09-13'::date
  AND status in ('Arrived', 'Departed')
  AND departure_city = 'Санкт-Петербург'
ORDER BY arrival_city;


-- 18.	Вывести перелёт(ы) с максимальной стоимостью всех билетов
INSERT INTO bookings.results (id, response)
SELECT 18 as id, tmp.flight_id
FROM (
         SELECT tf.flight_id
              , SUM(tf.amount)                             AS amount
              , RANK() OVER (ORDER BY SUM(tf.amount) DESC) AS rnk
         FROM bookings.ticket_flights tf
             JOIN flights f ON f.flight_id = tf.flight_id
         WHERE f.status != 'Cancelled'
         GROUP BY tf.flight_id
         ORDER BY SUM(tf.amount) DESC
     ) tmp
WHERE tmp.rnk = 1
ORDER BY tmp.flight_id;


-- 19.	Выбрать дни в которых было осуществлено минимальное количество перелётов
INSERT INTO bookings.results (id, response)
SELECT 19 as id, tmp.actual_departure
FROM (
         SELECT COUNT(actual_departure::date)
              , actual_departure::date as actual_departure
              , RANK() OVER (ORDER BY COUNT(actual_departure::date)) AS rnk
         FROM bookings.flights
         WHERE status != 'Cancelled'
           AND actual_departure IS NOT NULL
         GROUP BY actual_departure::date
         ORDER BY COUNT(actual_departure::date)
     ) tmp
WHERE tmp.rnk = 1
ORDER BY tmp.actual_departure;


-- 20.	Вывести среднее количество вылетов в день из Москвы за 09 месяц 2016 года
INSERT INTO bookings.results (id, response)
SELECT 20 as id, count(flight_id) / 30 as avg_flight_num
FROM bookings.flights_v
WHERE status in ('Arrived', 'Departed')
  AND departure_city = 'Москва'
  AND date_trunc('month',actual_departure)::date = '2016-09-01'::date;


-- 21.	Вывести топ 5 городов у которых среднее время перелета до пункта назначения больше 3 часов
INSERT INTO bookings.results (id, response)
SELECT 21 as id, departure_city
FROM bookings.flights_v
WHERE status = 'Arrived'
GROUP BY departure_city
HAVING avg(actual_duration) > INTERVAL '3 hours'
ORDER BY avg(actual_duration) DESC
LIMIT 5;