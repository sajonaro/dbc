-- Test database initialization script for Database Commander

-- Create some test tables with sample data
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    title VARCHAR(200) NOT NULL,
    content TEXT,
    published_at TIMESTAMP,
    view_count INTEGER DEFAULT 0
);

CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    post_id INTEGER REFERENCES posts(id),
    user_id INTEGER REFERENCES users(id),
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO users (username, email, is_active) VALUES
    ('alice', 'alice@example.com', true),
    ('bob', 'bob@example.com', true),
    ('charlie', 'charlie@example.com', false),
    ('diana', 'diana@example.com', true);

INSERT INTO posts (user_id, title, content, published_at, view_count) VALUES
    (1, 'First Post', 'This is Alice''s first post about database design.', NOW() - INTERVAL '2 days', 150),
    (1, 'SQL Tips', 'Some useful SQL optimization tips.', NOW() - INTERVAL '1 day', 89),
    (2, 'Hello World', 'Bob''s introduction to the community.', NOW() - INTERVAL '3 days', 234),
    (4, 'PostgreSQL Features', 'Exploring advanced PostgreSQL features.', NOW() - INTERVAL '5 hours', 42);

INSERT INTO comments (post_id, user_id, content) VALUES
    (1, 2, 'Great post! Very informative.'),
    (1, 4, 'Thanks for sharing this.'),
    (2, 3, 'Excellent tips!'),
    (3, 1, 'Welcome to the community, Bob!'),
    (3, 4, 'Nice to meet you!'),
    (4, 1, 'PostgreSQL is awesome!');

-- Create some additional schemas for testing
CREATE SCHEMA analytics;

CREATE TABLE analytics.page_views (
    id SERIAL PRIMARY KEY,
    page_url VARCHAR(500),
    user_id INTEGER,
    viewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    session_id VARCHAR(100)
);

INSERT INTO analytics.page_views (page_url, user_id, session_id) VALUES
    ('/home', 1, 'sess_001'),
    ('/about', 1, 'sess_001'),
    ('/posts/1', 2, 'sess_002'),
    ('/home', 4, 'sess_003');

-- Create a view for testing
CREATE VIEW user_post_summary AS
SELECT 
    u.username,
    u.email,
    COUNT(p.id) as post_count,
    SUM(p.view_count) as total_views
FROM users u
LEFT JOIN posts p ON u.id = p.user_id
GROUP BY u.id, u.username, u.email;

-- Display information
SELECT 'Database initialized successfully!' as status;
SELECT 'Total users: ' || COUNT(*) FROM users;
SELECT 'Total posts: ' || COUNT(*) FROM posts;
SELECT 'Total comments: ' || COUNT(*) FROM comments;