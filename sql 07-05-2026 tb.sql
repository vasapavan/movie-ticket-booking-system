

-- create table theatre (
-- theatre_id serial ,
-- name varchar(50) not null,
-- location varchar(50) not null,
-- primary key(theatre_id)
-- );
-- create table screen(
-- screen_id serial,
-- screen_no int NOT NULL,
-- theatre_id int NOT NULL,
-- primary key(screen_id),
-- foreign key(theatre_id) references theatre(theatre_id)
-- );
-- create table movie (
-- movie_id serial,
-- title varchar(50) not NULL,
-- language VARCHAR(50) not NULL,
-- genre varchar(50) not NULL,
-- duration int not NULL,
-- category varchar(20) not null,
-- primary key(movie_id)
-- );
-- create table users(
-- user_id serial ,
-- name varchar(50) not NULL,
-- age int not NULL,
-- email varchar(100) not NULL unique,
-- primary key(user_id)
-- );
-- create table shows (
-- show_id serial ,
-- stime varchar(50) not null,
-- sdate varchar(50) not NULL,
-- screen_id int not null,
-- foreign key(screen_id) references screen(screen_id),
-- primary key(show_id)
-- );
-- create table seat(
-- seat_id serial,
-- seat_no int not null,
-- seat_type varchar(50) not NULL,
-- amount int not NULL,
-- screen_id int not null,
-- foreign key(screen_id) references screen(screen_id),
-- primary key(seat_id)
-- );
-- create table booking(
-- user_id int not null,
-- seat_id int not null,
-- movie_id int not null,
-- show_id int not null,
-- primary key(user_id,seat_id,movie_id,show_id),
-- foreign key(user_id) references users(user_id),
-- foreign key(seat_id) references seat(seat_id),
-- foreign key(movie_id) references movie(movie_id),
-- foreign key(show_id) references shows(show_id)
-- );
-- create table payment(
-- payment_id serial,
-- payment_type varchar(50) not null,
-- amount int not null,
-- status varchar not null,
-- discount int ,
-- primary key(payment_id)
-- );
-- create table transactions(
-- payment_id int not null,
-- user_id int not null,
-- seat_id int not null,
-- movie_id int not null,
-- show_id int not null,
-- transactioned_time timestamp default current_timestamp,
-- primary key(user_id,seat_id,movie_id,show_id,payment_id),
-- foreign key(user_id) references users(user_id),
-- foreign key(seat_id) references seat(seat_id),
-- foreign key(movie_id) references movie(movie_id),
-- foreign key(show_id) references shows(show_id),
-- foreign key(payment_id) references payment(payment_id)
-- );
-- create table review(
-- user_id int not null,
-- movie_id int not null,
-- rating int not null,
-- opinion varchar(1000) ,
-- primary key(user_id,movie_id),
-- foreign key(movie_id) references movie(movie_id),
-- foreign key(user_id) references users(user_id)
-- );
-- create table alloted(
-- movie_id int not null,
-- show_id int not null,
-- primary key(movie_id,show_id),
-- foreign key(movie_id) references movie(movie_id),
-- foreign key(show_id) references shows(show_id)
-- );

-- create table available_for(
-- show_id int not null,
-- seat_id int not null,
-- status varchar(30) default 'available',
-- foreign key(show_id) references shows(show_id),
-- foreign key(show_id) references shows(show_id),
-- primary key (show_id,seat_id)
-- );

-- CREATE OR REPLACE FUNCTION movie_revenue(m_id INT)
-- RETURNS INT
-- LANGUAGE plpgsql
-- AS $$
-- DECLARE
--     total_rev INT;
-- BEGIN

--     SELECT SUM(p.amount - COALESCE(p.discount,0))
--     INTO total_rev
--     FROM transactions t
--     JOIN payment p 
--     ON t.payment_id = p.payment_id
--     WHERE t.movie_id = m_id
--     AND p.status = 'success';

--     RETURN COALESCE(total_rev,0);

-- END;
-- $$;

-- CREATE OR REPLACE FUNCTION highest_rated_movies_wi(g_name VARCHAR)
-- RETURNS TABLE(
--     movie_id INT,
--     title VARCHAR,
--     avg_rating NUMERIC
-- )
-- LANGUAGE plpgsql
-- AS $$
-- BEGIN
--     RETURN QUERY
--     WITH MovieRatings AS (
--         SELECT 
--             m.movie_id,
--             m.title,
--             AVG(r.rating)::NUMERIC(3,2) AS rating,
--             RANK() OVER (ORDER BY AVG(r.rating) DESC) as rnk
--         FROM movie m
--         JOIN review r ON m.movie_id = r.movie_id
--         WHERE m.genre = g_name
--         GROUP BY m.movie_id, m.title
--     )
--     SELECT 
--         mr.movie_id, 
--         mr.title, 
--         mr.rating
--     FROM MovieRatings mr
--     WHERE mr.rnk = 1; -- This captures everyone tied for 1st place
-- END;
-- $$;
-- select * from highest_rated_movies_with_ties('Action');
-- #####################################################################################################################
-- CREATE OR REPLACE FUNCTION sid_from_sno(s_id INT)
-- RETURNS INT
-- LANGUAGE plpgsql
-- AS $$
-- DECLARE
--     s_no INT;
-- BEGIN 
--     SELECT screen_no 
--     INTO s_no
--     FROM screen 
--     WHERE screen_id = s_id;

--     RETURN s_no;
-- END;
-- $$;

-- CREATE OR REPLACE FUNCTION get_theatres_by_movie(m_id INT)
-- RETURNS TABLE(
--     theatre_id INT,
--     theatre_name VARCHAR,
--     location VARCHAR
-- )
-- AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT DISTINCT t.theatre_id, t.name, t.location
--     FROM theatre t
--     JOIN screen sc ON t.theatre_id = sc.theatre_id
--     JOIN shows sh ON sc.screen_id = sh.screen_id
--     JOIN alloted a ON sh.show_id = a.show_id
--     WHERE a.movie_id = m_id;
-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE OR REPLACE FUNCTION get_shows_by_movie_theatre(m_id INTEGER, t_id INTEGER)
-- RETURNS TABLE(sho_id INTEGER, sho_time VARCHAR(50), sho_date VARCHAR(50), scree_id INTEGER)
-- AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT sh.show_id, sh.stime, sh.sdate, sh.screen_id
--     FROM shows sh
--     JOIN alloted a ON sh.show_id = a.show_id
--     JOIN screen sc ON sh.screen_id = sc.screen_id
--     WHERE a.movie_id = m_id
--       AND sc.theatre_id = t_id;
-- END;
-- $$ LANGUAGE plpgsql;

-- create or replace function get_movies()
-- returns setof movie
-- language plpgsql
-- as $$
-- begin
--     return query
--     select * from movie;
-- end;
-- $$;

-- CREATE OR REPLACE FUNCTION get_available_seats(s_id INT)
-- RETURNS TABLE(
--     seat_id INT,
--     seat_no INT,
--     seat_type VARCHAR,
--     amount INT
-- )
-- AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT st.seat_id, st.seat_no, st.seat_type, st.amount
--     FROM seat st
--     JOIN available_for af ON st.seat_id = af.seat_id
--     WHERE af.show_id = s_id
--       AND af.status = 'available';
-- END;
-- $$ LANGUAGE plpgsql;

-- ALTER TABLE booking
-- ADD COLUMN booking_time TIMESTAMP DEFAULT NOW(); 

-- CREATE OR REPLACE PROCEDURE create_booking(
--     u_id INT,
--     s_id INT,
--     m_id INT,
--     sh_id INT
-- )
-- LANGUAGE plpgsql
-- AS $$
-- BEGIN
--     INSERT INTO booking(
--         user_id,
--         seat_id,
--         movie_id,
--         show_id,
--         booking_time
--     )
--     VALUES (
--         u_id,
--         s_id,
--         m_id,
--         sh_id,
--         NOW()
--     );
-- END;
-- $$;

-- CREATE OR REPLACE FUNCTION mark_seat_booked()
-- RETURNS TRIGGER AS $$
-- BEGIN
--     UPDATE available_for
--     SET status = 'booked'
--     WHERE show_id = NEW.show_id
--       AND seat_id = NEW.seat_id;

--     RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE TRIGGER trg_after_booking_insert
-- AFTER INSERT ON booking
-- FOR EACH ROW
-- EXECUTE FUNCTION mark_seat_booked();

-- CREATE OR REPLACE FUNCTION mark_seat_available()
-- RETURNS TRIGGER AS $$
-- BEGIN
--     UPDATE available_for
--     SET status = 'available'
--     WHERE show_id = OLD.show_id
--       AND seat_id = OLD.seat_id;

--     RETURN OLD;
-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE TRIGGER trg_after_booking_delete
-- AFTER DELETE ON booking
-- FOR EACH ROW
-- EXECUTE FUNCTION mark_seat_available();

-- CREATE OR REPLACE PROCEDURE confirm_payment(
--     u_id INT,
--     s_id INT,
--     m_id INT,
--     sh_id INT,
--     p_type VARCHAR,
--     amt INT,
--     disc INT
-- )
-- LANGUAGE plpgsql
-- AS $$
-- DECLARE
--     new_pid INT;
-- BEGIN
--     -- Step 1: Insert into payment (auto generates payment_id)
--     INSERT INTO payment(payment_type, amount, status, discount)
--     VALUES (p_type, amt, 'success', disc)
--     RETURNING payment_id INTO new_pid;

--     -- Step 2: Insert into transactions using same payment_id
--     INSERT INTO transactions(
--         payment_id,
--         user_id,
--         seat_id,
--         movie_id,
--         show_id
--     )
--     VALUES (
--         new_pid,
--         u_id,
--         s_id,
--         m_id,
--         sh_id
--     );

-- END;
-- $$;

-- CREATE OR REPLACE PROCEDURE clear_expired_bookings()
-- LANGUAGE plpgsql
-- AS $$
-- BEGIN
--     DELETE FROM booking b
--     WHERE b.booking_time < NOW() - INTERVAL '5 minutes'
--     AND NOT EXISTS (
--         SELECT 1
--         FROM transactions t
--         WHERE t.seat_id = b.seat_id
--           AND t.show_id = b.show_id
--     );
-- END;
-- $$;
 
-- insert into booking
-- values (1,1,1,1)

-- insert into booking 
-- values (2,2,1,1)

-- call confirm_payment(1,1,1,1,'card',500,10)
-- call clear_expired_bookings()
-- select * from booking
-- select * from available_for where seat_id=1 and show_id=1

-- update available_for
-- set status='available'
-- where seat_id=1 and show_id=1

-- delete from booking
-- delete from transactions
-- delete from payment

----------------------------roles cus and admin ------------------------------------------------------
-- CREATE ROLE customer LOGIN PASSWORD 'cust123';

-- GRANT SELECT ON movie TO customer;
-- GRANT SELECT ON theatre TO customer;
-- GRANT SELECT ON screen TO customer;
-- GRANT SELECT ON shows TO customer;
-- GRANT SELECT ON seat TO customer;
-- GRANT SELECT ON available_for TO customer;

-- GRANT INSERT ON review TO customer;

-- GRANT EXECUTE ON PROCEDURE create_booking TO customer;
-- GRANT EXECUTE ON PROCEDURE confirm_payment TO customer;

-- CREATE ROLE admin LOGIN PASSWORD 'admin123';

-- GRANT ALL ON movie TO admin;
-- GRANT ALL ON theatre TO admin;
-- GRANT ALL ON screen TO admin;
-- GRANT ALL ON shows TO admin;
-- GRANT ALL ON seat TO admin;
-- GRANT ALL ON alloted TO admin;

-- GRANT ALL ON booking TO admin;
-- GRANT ALL ON payment TO admin;
-- GRANT ALL ON transactions TO admin;
-- GRANT ALL ON review TO admin;

-- following three procedures are for admin role:
--1)
-- CREATE OR REPLACE PROCEDURE admin_assign_movie_to_theatre(
--     m_id INT,
--     sc_id INT,
--     show_time VARCHAR,
--     show_date VARCHAR
-- )
-- LANGUAGE plpgsql
-- AS $$
-- DECLARE
--     new_show_id INT;
-- BEGIN
    
--     INSERT INTO shows(stime, sdate, screen_id)
--     VALUES (show_time, show_date, sc_id)
--     RETURNING show_id INTO new_show_id;

    
--     INSERT INTO alloted(movie_id, show_id)
--     VALUES (m_id, new_show_id);

-- END;
-- $$;
--2)
-- CREATE OR REPLACE FUNCTION admin_total_revenue()
-- RETURNS INT AS $$
-- DECLARE total INT;
-- BEGIN
--     SELECT SUM(amount)
--     INTO total
--     FROM payment
--     WHERE status = 'success';

--     RETURN COALESCE(total, 0);
-- END;
-- $$ LANGUAGE plpgsql;
--3)
-- CREATE OR REPLACE FUNCTION admin_view_all_bookings()
-- RETURNS TABLE(
--     user_id INT,
--     movie_id INT,
--     show_id INT,
--     seat_id INT
-- )
-- AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT user_id, movie_id, show_id, seat_id
--     FROM booking;
-- END;
-- $$ LANGUAGE plpgsql;
-- grant execute on PROCEDURE admin_assign_movie_to_theatre to admin;
-- grant execute on function admin_total_revenue to admin;
-- grant execute on function admin_view_all_bookings to admin;

-------------------------payment manager role--------------------------------
-- CREATE ROLE payment_manager LOGIN PASSWORD 'pay123';
-- GRANT USAGE ON SCHEMA public TO payment_manager;

-- GRANT SELECT ON payment TO payment_manager;
-- GRANT SELECT ON transactions TO payment_manager;

-- CREATE OR REPLACE FUNCTION pm_peak_hour()
-- RETURNS TABLE(
--     hour INT,
--     total_revenue INT
-- )
-- AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT EXTRACT(HOUR FROM t.transactioned_time)::INT, SUM(p.amount)
--     FROM transactions t
--     JOIN payment p ON t.payment_id = p.payment_id
--     WHERE p.status = 'success'
--     GROUP BY EXTRACT(HOUR FROM t.transactioned_time)
--     ORDER BY SUM(p.amount) DESC
--     LIMIT 1;
-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE OR REPLACE FUNCTION pm_weekly_growth()
-- RETURNS TABLE(
--     pay_date DATE,
--     total_amount INT
-- )
-- AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT DATE(t.transactioned_time), SUM(p.amount)
--     FROM transactions t
--     JOIN payment p ON t.payment_id = p.payment_id
--     WHERE t.transactioned_time >= CURRENT_DATE - INTERVAL '7 days'
--       AND p.status = 'success'
--     GROUP BY DATE(t.transactioned_time)
--     ORDER BY DATE(t.transactioned_time);
-- END;
-- $$ LANGUAGE plpgsql;

-- grant execute on function pm_peak_hour to payment_manager;
-- grant execute on function pm_weekly_growth to payment_manager;

-------------------------------------------last two triggers------------------
--3rd trigger
-- CREATE OR REPLACE FUNCTION init_seats_for_show()
-- RETURNS TRIGGER AS $$
-- BEGIN
--     INSERT INTO available_for(show_id, seat_id, status)
--     SELECT NEW.show_id, s.seat_id, 'available'
--     FROM seat s
--     WHERE s.screen_id = NEW.screen_id;

--     RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE TRIGGER trg_init_seats
-- AFTER INSERT ON shows
-- FOR EACH ROW
-- EXECUTE FUNCTION init_seats_for_show();

--4th trigger
-- CREATE OR REPLACE FUNCTION check_review_validity()
-- RETURNS TRIGGER AS $$
-- BEGIN
--     IF NOT EXISTS (
--         SELECT 1
--         FROM transactions
--         WHERE user_id = NEW.user_id
--           AND movie_id = NEW.movie_id
--     ) THEN
--         RAISE EXCEPTION 'User cannot review without watching the movie';
--     END IF;

--     RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE TRIGGER trg_check_review
-- BEFORE INSERT ON review
-- FOR EACH ROW
-- EXECUTE FUNCTION check_review_validity();

--------------------------------procedure for user to review------
-- CREATE OR REPLACE PROCEDURE add_review(
--     u_id INT,
--     m_id INT,
--     rating_val INT,
--     opinion_text VARCHAR
-- )
-- LANGUAGE plpgsql
-- AS $$
-- BEGIN
--     INSERT INTO review(
--         user_id,
--         movie_id,
--         rating,
--         opinion
--     )
--     VALUES (
--         u_id,
--         m_id,
--         rating_val,
--         opinion_text
--     );
-- END;
-- $$;

------------------------------- views -------------------------
--1)
-- CREATE VIEW payment_summary_view AS
-- SELECT 
--     t.user_id,
--     t.movie_id,
--     p.amount,
--     p.status,
--     t.transactioned_time
-- FROM transactions t
-- JOIN payment p ON t.payment_id = p.payment_id;
-- GRANT SELECT ON payment_summary_view TO payment_manager;

--2)
-- CREATE VIEW review_summary_view AS
-- SELECT 
--     m.movie_id,
--     m.title,
--     AVG(r.rating) AS avg_rating,
--     COUNT(r.user_id) AS total_reviews
-- FROM movie m
-- JOIN review r ON m.movie_id = r.movie_id
-- GROUP BY m.movie_id, m.title;
-- GRANT SELECT ON review_summary_view TO customer;
-- GRANT SELECT ON review_summary_view TO admin;

--3)
-- CREATE VIEW show_status_view AS
-- SELECT 
--     sh.show_id,
--     m.title AS movie_name,
--     COUNT(b.seat_id) AS booked_seats,
--     50 AS total_seats,
--     CASE
--         WHEN COUNT(b.seat_id) >= 50 THEN 'Housefull'
--         ELSE 'Available'
--     END AS status
-- FROM shows sh
-- JOIN alloted a ON sh.show_id = a.show_id
-- JOIN movie m ON a.movie_id = m.movie_id
-- LEFT JOIN booking b ON sh.show_id = b.show_id
-- GROUP BY sh.show_id, m.title;
-- GRANT SELECT ON show_status_view TO customer;
-- GRANT SELECT ON show_status_view TO admin;
------------------------------------------- INDICES ----------------
-- CREATE INDEX idx_booking_show_seat
-- ON booking(show_id, seat_id);

-- CREATE INDEX idx_transaction_time
-- ON transactions(transactioned_time);

-- CREATE INDEX idx_screen_theatre
-- ON screen(theatre_id);

-- CREATE INDEX idx_movie_title
-- ON movie(title);

-- CREATE INDEX idx_review_movie
-- ON review(movie_id);

-- CREATE INDEX Idx_payment_id
-- ON payment(payment_id);

-- create index idx_users_email on users using HASH(email);

-- ALTER TABLE users ADD COLUMN password TEXT;

-- CREATE OR REPLACE PROCEDURE signup_user(
--     p_name TEXT,
--     p_email TEXT,
--     p_age INT,
--     p_password TEXT
-- )
-- LANGUAGE plpgsql
-- AS $$
-- BEGIN
--     INSERT INTO users(name, email, age, password)
--     VALUES (p_name, p_email, p_age, p_password);
-- END;
-- $$;

-- CREATE OR REPLACE FUNCTION login_user(p_email TEXT, p_password TEXT)
-- RETURNS TABLE(user_id INTEGER, name VARCHAR(50))
-- AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT u.user_id, u.name
--     FROM users u
--     WHERE u.email = p_email
--       AND u.password = p_password;
-- END;
-- $$ LANGUAGE plpgsql;
---------------------transactions-------------
-------ticket canceling--------
-- BEGIN;

-- SAVEPOINT sp_before_delete;


-- DELETE FROM booking
-- WHERE user_id = 1 AND show_id = 101;

-- SAVEPOINT sp_before_update;

-- UPDATE seat
-- SET status = 'available'
-- WHERE seat_id = 10;


-- COMMIT;
----------------
-- BEGIN;

-- SAVEPOINT sp_before_update;


-- UPDATE users
-- SET name = 'Pavan Kumar',
--     age = 23
-- WHERE user_id = 1;

-- SAVEPOINT sp_after_update;

-- UPDATE users
-- SET email = 'pavan@gmail.com'
-- WHERE user_id = 1;

-- COMMIT;

-- BEGIN;

-- SAVEPOINT sp_before_show;

-- INSERT INTO show(show_id, movie_id, theatre_id, show_time)
-- VALUES (201, 10, 5, NOW());

-- SAVEPOINT sp_before_seats;

-- INSERT INTO seat(seat_id, show_id, status)
-- SELECT generate_series(1, 50), 201, 'available';

-- COMMIT;

