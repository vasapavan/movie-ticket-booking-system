import psycopg2  
from flask import Flask, request, jsonify  

from apscheduler.schedulers.background import BackgroundScheduler
from flask_cors import  CORS
app = Flask(__name__)  
CORS(app, resources={r"/*": {"origins": "*"}}, supports_credentials=True)
@app.after_request
def after_request(response):
    response.headers.add('Access-Control-Allow-Origin', '*')
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type,Authorization')
    response.headers.add('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS')
    return response

conn = psycopg2.connect(  
    database="movie ticket booking",  
    user="postgres",  
    password="Rithvik@123",  
    host="localhost",  
    port="5432"  
)
conn.autocommit=True

#--------------customer APIs---------
@app.route('/movies', methods=['GET'])
def get_movies():
    try:
        cur = conn.cursor()
        cur.execute("SELECT m.movie_id, m.title, ROUND(AVG(r.rating), 1) as avg_rating FROM movie m LEFT JOIN review r ON m.movie_id = r.movie_id GROUP BY m.movie_id, m.title;")
        movies = cur.fetchall()
        cur.close()

        return jsonify(movies)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/my_bookings/<int:user_id>', methods=['GET'])
def get_my_bookings(user_id):
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT 
                tr.user_id,
                m.title,
                t.name,
                s.stime,
                s.sdate,
                sc.screen_id,
                tr.seat_id,
                p.payment_type,
                p.amount,
                p.discount,
                tr.transactioned_time
            FROM transactions tr
            JOIN payment p ON tr.payment_id = p.payment_id
            JOIN shows s ON tr.show_id = s.show_id
            JOIN movie m ON tr.movie_id = m.movie_id
            JOIN screen sc ON s.screen_id = sc.screen_id
            JOIN theatre t ON sc.theatre_id = t.theatre_id
            WHERE tr.user_id = %s
              AND p.status = 'success'
            ORDER BY tr.transactioned_time DESC;
        """, (user_id,))
        data = cur.fetchall()
        cur.close()
        return jsonify([{
            "user_id": row[0],
            "movie": row[1],
            "theatre": row[2],
            "show_time": row[3],
            "show_date": row[4],
            "screen": row[5],
            "seat": row[6],
            "payment_type": row[7],
            "amount": str(row[8]),
            "discount": str(row[9]),
            "transactioned_time": str(row[10])
        } for row in data])
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/admin/show_times', methods=['GET'])
def get_show_times():
    role = request.args.get('role')
    if role != "admin":
        return "Unauthorized", 403
    cur = conn.cursor()
    cur.execute("SELECT DISTINCT stime FROM shows ORDER BY stime;")
    data = cur.fetchall()
    cur.close()
    return jsonify([row[0] for row in data])

@app.route('/search', methods=['GET'])
def search_movie():
    try:
        name = request.args.get('name')

        if not name:
            return jsonify({"error": "name parameter required"}), 400

        cur = conn.cursor()
        cur.execute("""
            SELECT m.movie_id, m.title, ROUND(AVG(r.rating), 1) as avg_rating
            FROM movie m
            LEFT JOIN review r ON m.movie_id = r.movie_id
            WHERE m.title ILIKE %s
            GROUP BY m.movie_id, m.title;
        """, ('%' + name + '%',))
        result = cur.fetchall()
        cur.close()

        return jsonify(result)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/theatres/<int:movie_id>', methods=['GET'])
def get_theatres(movie_id):
    try:
        cur = conn.cursor()
        cur.execute("SELECT * FROM get_theatres_by_movie(%s);", (movie_id,))
        data = cur.fetchall()
        cur.close()

        return jsonify(data)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/shows', methods=['POST'])
def get_shows():
    try:
        data = request.json

        if not data or 'movie_id' not in data or 'theatre_id' not in data:
            return jsonify({"error": "movie_id and theatre_id required"}), 400

        cur = conn.cursor()
        cur.execute("SELECT * FROM get_shows_by_movie_theatre(%s, %s);",
                    (data['movie_id'], data['theatre_id']))
        shows = cur.fetchall()
        cur.close()

        return jsonify(shows)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/seats/<int:show_id>', methods=['GET'])
def get_seats(show_id):
    try:
        cur = conn.cursor()
        cur.execute("SELECT * FROM get_available_seats(%s);", (show_id,))
        seats = cur.fetchall()
        cur.close()

        return jsonify(seats)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/book_seat', methods=['POST'])
def book():
    try:
        data = request.json

        required = ['user_id', 'seat_id', 'movie_id', 'show_id']
        if not data or not all(k in data for k in required):
            return jsonify({"error": "Missing required fields"}), 400

        cur = conn.cursor()
        cur.execute("CALL create_booking(%s, %s, %s, %s);",
                    (data['user_id'], data['seat_id'],
                     data['movie_id'], data['show_id']))
        conn.commit()
        cur.close()

        return jsonify({"message": "Seat booked"})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/pay', methods=['POST'])
def pay():
    try:
        data = request.json

        if str(data['code']) != "12345":
            return jsonify({"message": "Payment Failed: Invalid Code"}), 400

        cur = conn.cursor()

        cur.execute("CALL confirm_payment(%s, %s, %s, %s, %s, %s, %s);",
                    (data['user_id'], data['seat_id'],
                     data['movie_id'], data['show_id'],
                     data['type'], data['amount'], data['discount']))
        conn.commit()

        cur.execute("""
            SELECT b.user_id, b.seat_id, s.stime, s.screen_id,
                m.title, t.name,
                ROUND(AVG(r.rating), 1) as avg_rating
            FROM booking b
            JOIN shows s ON b.show_id = s.show_id
            JOIN movie m ON b.movie_id = m.movie_id
            JOIN screen sc ON s.screen_id = sc.screen_id
            JOIN theatre t ON sc.theatre_id = t.theatre_id
            LEFT JOIN review r ON m.movie_id = r.movie_id
            WHERE b.user_id = %s AND b.show_id = %s
            GROUP BY b.user_id, b.seat_id, s.stime, s.screen_id, m.title, t.name, b.booking_time
            ORDER BY b.booking_time DESC
            LIMIT 1;
        """, (data['user_id'], data['show_id']))

        details = cur.fetchone()
        cur.close()

        return jsonify({
            "message": "Payment Successful",
            "booking_id": str(details[0]),
            "seat_id": details[1],
            "show_time": str(details[2]),
            "screen_id": details[3],
            "movie_name": details[4],
            "theatre_name": details[5],
            "rating": str(details[6]) if details[6] else "No ratings yet"
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/reviews/<int:movie_id>', methods=['GET'])
def get_reviews(movie_id):
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT r.user_id, r.rating, r.opinion
            FROM review r
            WHERE r.movie_id = %s
            ORDER BY r.movie_id DESC;
        """, (movie_id,))
        data = cur.fetchall()
        cur.close()
        return jsonify(data)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/review', methods=['POST'])
def review():
    try:
        data = request.json

        required = ['user_id', 'movie_id', 'rating', 'opinion']
        if not data or not all(k in data for k in required):
            return jsonify({"error": "Missing required fields"}), 400

        cur = conn.cursor()
        cur.execute("CALL add_review(%s, %s, %s, %s);",
                    (data['user_id'], data['movie_id'],
                     data['rating'], data['opinion']))
        conn.commit()
        cur.close()

        return jsonify({"message": "Review added"})

    except Exception as e:
        return jsonify({"error": str(e)}), 500


def clear_expired():
    try:
        conn = psycopg2.connect(
            database="movie ticket booking",
            user="postgres",
            password="Rithvik@123",
            host="localhost",
            port="5432"
        )
        cur = conn.cursor()
        cur.execute("CALL clear_expired_bookings();")
        conn.commit()
        cur.close()
        conn.close()
        print("Expired bookings cleared")
    except Exception as e:
        print("Error:", e)


#-------------admin APIs----------
@app.route('/admin/assign_movie', methods=['POST'])
def assign_movie():
    role = request.args.get('role')

    if role != "admin":
        return "Unauthorized", 403
    
    data = request.json

    cur = conn.cursor()
    cur.execute("CALL admin_assign_movie_to_theatre(%s, %s, %s, %s);",
                (data['movie_id'], data['screen_id'],
                 data['time'], data['date']))
    conn.commit()
    cur.close()

    return jsonify({"message": "Movie assigned successfully"})

@app.route('/admin/revenue', methods=['GET'])
def get_revenue():
    role = request.args.get('role')

    if role != "admin":
        return "Unauthorized", 403

    cur = conn.cursor()
    cur.execute("SELECT admin_total_revenue();")
    result = cur.fetchone()
    cur.close()

    return jsonify({"total_revenue": result[0]})

@app.route('/admin/bookings', methods=['GET'])
def view_bookings():
    role = request.args.get('role')

    if role != "admin":
        return "Unauthorized", 403
    cur = conn.cursor()
    cur.execute("SELECT * FROM admin_view_all_bookings();")
    data = cur.fetchall()
    cur.close()

    return jsonify(data)

#---------payment manager---------
@app.route('/pm/peak_hour', methods=['GET'])
def pm_peak_hour_api():
    role = request.args.get('role')

    if role != "payment_manager":
        return "Unauthorized", 403

    cur = conn.cursor()
    cur.execute("SELECT * FROM pm_peak_hour();")
    data = cur.fetchall()
    cur.close()

    return jsonify(data)

@app.route('/pm/weekly_growth', methods=['GET'])
def pm_weekly_growth_api():
    role = request.args.get('role')

    if role != "payment_manager":
        return "Unauthorized", 403

    cur = conn.cursor()
    cur.execute("SELECT * FROM pm_weekly_growth();")
    data = cur.fetchall()
    cur.close()

    return jsonify(data)

@app.route('/pm/payment_summary', methods=['GET'])
def payment_summary():
    role = request.args.get('role')

    if role != "payment_manager":
        return "Unauthorized", 403

    cur = conn.cursor()
    cur.execute("SELECT * FROM payment_summary_view;")
    data = cur.fetchall()
    cur.close()

    return jsonify(data)

@app.route('/reviews/summary', methods=['GET'])
def review_summary():
    role = request.args.get('role')

    if role not in ["customer", "admin"]:
        return "Unauthorized", 403

    cur = conn.cursor()
    cur.execute("SELECT * FROM review_summary_view;")
    data = cur.fetchall()
    cur.close()

    return jsonify(data)

@app.route('/shows/status', methods=['GET'])
def show_status():
    role = request.args.get('role')

    if role not in ["customer", "admin"]:
        return "Unauthorized", 403

    cur = conn.cursor()
    cur.execute("SELECT * FROM show_status_view;")
    data = cur.fetchall()
    cur.close()

    return jsonify(data)

@app.route('/signup', methods=['POST'])
def signup():
    try:
        data = request.json

        required = ['name', 'email', 'age', 'password']
        if not data or not all(k in data for k in required):
            return jsonify({"error": "Missing fields"}), 400

        cur = conn.cursor()
        cur.execute("CALL signup_user(%s, %s, %s, %s);",
                    (data['name'], data['email'],
                     data['age'], data['password']))
        conn.commit()
        cur.close()

        return jsonify({"message": "User registered"})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/login', methods=['POST'])
def login():
    try:
        data = request.json

        if not data or 'email' not in data or 'password' not in data:
            return jsonify({"error": "Email and password required"}), 400

        cur = conn.cursor()
        cur.execute("SELECT * FROM login_user(%s, %s);",
                    (data['email'], data['password']))
        user = cur.fetchone()
        cur.close()

        if not user:
            return jsonify({"message": "Invalid credentials"}), 401

        email = data['email']

        if email == "admin@gmail.com":
            role = "admin"
        elif email == "pm@gmail.com":
            role = "payment_manager"
        else:
            role = "customer"

        return jsonify({
            "message": "Login successful",
            "user_id": user[0],
            "name": user[1],
            "role": role
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    scheduler = BackgroundScheduler()
    scheduler.add_job(clear_expired, 'interval', minutes=1)
    scheduler.start()
    app.run(debug=True)
