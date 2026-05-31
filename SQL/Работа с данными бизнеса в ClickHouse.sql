--Работа с данными бизнеса в ClickHouse

--Задание 1

SELECT a_gorod_obl.usage_geo_id_name as town, 
	   round(sumIf(a_gorod_obl.hours, a_gorod_obl.usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')),0) as total_hours,
	   round(sumIf(a_gorod_obl.hours, a_gorod_obl.usage_platform_ru LIKE 'Букмейт iOS'),0) as hours_for_iOS,
	   round(sumIf(a_gorod_obl.hours, a_gorod_obl.usage_platform_ru LIKE 'Букмейт Android'),0) as hours_for_Android
FROM (SELECT *
		FROM source_db.audition a 
		WHERE a.usage_country_name = 'Россия' 
		and a.usage_geo_id_name NOT LIKE '%федеральный%') as a_gorod_obl
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;

--Москва и Санкт-Петербург — лидеры по популярности сервиса, с большим отрывом от остальных городов и регионов,что ожидаемо, учитывая их население и уровень цифровой активности.
--В Москве и Московской области суммарное время значительно выше, чем в других регионах, что говорит о высокой вовлечённости пользователей.
--В большинстве регионов Android-платформа показывает большую активность по времени, чем iOS. Это может отражать более широкое распространение Android-устройств в России.
--Включение в топ таких регионов, как Екатеринбург, Краснодар, Новосибирск, Ростов-на-Дону и Казань, указывает на значительный интерес к сервису в крупных городах и экономических центрах.
--Интересно, что в выборке есть агрегированные регионы, например, "Москва и Московская область" или "Санкт-Петербург и Ленинградская область", что может указывать на объединённые данные по городу и прилегающей области.

--Задание 2

SELECT c.main_content_name as book_name,
	   c.main_author_name as author_name,
	   round(sumIf(a.hours, c.main_content_type IN ('Book', 'Audiobook')),2) as total_hours_b_ab,
	   round(avgIf(a.hours, c.main_content_type LIKE 'Book'),2) as avg_hours_book,
	   round(avgIf(a.hours, c.main_content_type LIKE 'Audiobook'),2) as avg_hours_aud
FROM source_db.audition a
JOIN source_db.content c ON a.main_content_id = c.main_content_id
WHERE a.usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
GROUP BY 1,2
HAVING uniqExact(main_content_type) = 2
ORDER BY 3 DESC
LIMIT 5;

--Книги, популярные в обоих форматах (текст и аудио), имеют значительный суммарный объём прослушивания и прочтения, что говорит о широкой аудитории и разнообразии предпочтений.
--Среднее время прослушивания аудиокниг обычно выше, чем среднее время чтения текстовых книг, что логично, так как аудиокниги часто слушают целиком или дольше, а чтение может быть более фрагментированным.
--Лидер по суммарному количеству часов — книга Уолтера Айзексона «Илон Маск» — выделяется тем, что при очень высоком общем времени взаимодействия она имеет наименьшие средние показатели времени чтения и прослушивания среди топ-5. Это говорит о широкой заинтересованности пользователей, которые активно начинают читать или слушать книгу, но в среднем проводят с ней меньше времени, чем с другими популярными произведениями. Такая картина отражает высокий уровень первоначального интереса, но относительно низкую глубину вовлечённости.

Задание 3

WITH author_aud AS (
SELECT groupUniqArrayIf(main_author_name, main_content_type = 'Audiobook') as arr_authors
FROM source_db.content c
)

SELECT c.main_author_name  as author_name,
       round(sumIf(a.hours, c.main_content_type='Book' and a.usage_platform_ru LIKE '%Букмейт%'),2) as total_hours_books,
       uniqIf(main_content_id, (c.main_content_type='Book')>0) as count_text_books,
       round(avgIf(a.hours, c.main_content_type='Audiobook' and a.usage_platform_ru LIKE '%Букмейт%'),2) as avg_hours_mobil
FROM source_db.content c 
JOIN source_db.audition a ON c.main_content_id = a.main_content_id 
GROUP BY 1
HAVING has((SELECT arr_authors FROM author_aud), c.main_author_name)
ORDER BY 2 DESC
LIMIT 10;

--Высокая суммарная длительность чтения при относительно небольшом количестве уникальных текстовых книг (например, у Александры Лисиной — 1558 часов при 71 книге) говорит о высокой популярности и интенсивном потреблении контента именно этих книг. Это может означать, что книги автора читают многократно или они имеют большую среднюю длину.
--Дарья Донцова выделяется большим количеством уникальных текстовых книг (163), что свидетельствует о широкой библиотеке, но при этом средняя длительность прослушивания аудиокниг на мобильных устройствах ниже, чем у некоторых других авторов.
--Константин Муравьёв демонстрирует самый высокий средний показатель длительности прослушивания аудиокниг на мобильных устройствах (2.66 часа), что может указывать на более длинные или более вовлекающие аудиокниги.
--Ребекка Яррос имеет всего 2 уникальные текстовые книги, но при этом средняя длительность прослушивания аудиокниг достаточно высокая (1.74 часа), что может говорить о популярности именно аудиоформата у её аудитории.
--Виктор Пелевин, несмотря на умеренное количество текстовых книг (30), имеет самый низкий средний показатель длительности прослушивания аудиокниг (0.97 часа), что может указывать на более короткие аудиокниги или менее вовлекающий формат.
--Общее наблюдение: количество уникальных текстовых книг не всегда коррелирует с суммарной длительностью чтения или средней длительностью прослушивания аудиокниг. Это говорит о том, что популярность и вовлеченность аудитории зависят не только от объема библиотеки, но и от качества, формата и предпочтений пользователей.

--Задание 4

WITH user_hours AS (
    SELECT
        a.puid,
        a.usage_platform_ru as platform,
        c.main_content_type,
        sum(a.hours) as hours
    FROM source_db.audition a
    JOIN source_db.content c ON c.main_content_id = a.main_content_id
    WHERE a.usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
    	 and c.main_content_type IN ('Book', 'Audiobook')
    GROUP BY 1,2,3
),

--user_summary AS (
    SELECT
        puid,
        sum(hours) as total_hours,
        sumIf(hours, main_content_type = 'Book') as book_hours,
        sumIf(hours, main_content_type = 'Audiobook') as aud_hours,
        sumIf(hours, platform = 'Букмейт iOS') as ios_hours,
        sumIf(hours, platform = 'Букмейт Android') as android_hours
    FROM user_hours
    GROUP BY 1
),

user_segments AS (
    SELECT
        puid,
        total_hours,
        book_hours,
        aud_hours,
        if(ios_hours > android_hours, 'iOS', 'Android') as main_platform,
        CASE
            WHEN book_hours / total_hours >= 0.7 THEN 'Читатель'
            WHEN aud_hours / total_hours >= 0.7 THEN 'Слушатель'
            ELSE 'Оба'
        END as segment
    FROM user_summary
)

SELECT
    countIf(segment = 'Читатель' and main_platform = 'iOS') as `Читатель_iOS`,
    countIf(segment = 'Слушатель' and main_platform = 'iOS') as `Слушатель_iOS`,
    countIf(segment = 'Оба' and main_platform = 'iOS') as `Оба_iOS`,
    countIf(segment = 'Читатель' and main_platform = 'Android') as `Читатель_Android`,
    countIf(segment = 'Слушатель' and main_platform = 'Android') as `Слушатель_Android`,
    countIf(segment = 'Оба' and main_platform = 'Android') as `Оба_Android`
FROM user_segments;

--Для Android предположение о почти равном количестве слушателей и читателей подтверждается.
--Для iOS количество читателей больше, чем слушателей, но не в два раза, а примерно на 30%.

--Задание 5

WITH days_hours AS (
    SELECT
        c.main_content_type as content_type,
        CAST(a.msk_business_dt_str AS date) as dt,
        toDayOfWeek(toDate(a.msk_business_dt_str)) as day_of_week,
        sum(a.hours) as total_hours
    FROM source_db.audition a
    JOIN source_db.content c ON a.main_content_id = c.main_content_id
    WHERE a.usage_platform_ru LIKE '%Букмейт%'
      	and c.main_content_type IN ('Book', 'Audiobook')
    GROUP BY 1,2,3
)

SELECT
    content_type,
    round(avgIf(total_hours, day_of_week = 1), 2) as hours_mon,
    round(avgIf(total_hours, day_of_week = 2), 2) as hours_tue,
    round(avgIf(total_hours, day_of_week = 3), 2) as hours_wed,
    round(avgIf(total_hours, day_of_week = 4), 2) as hours_thu,
    round(avgIf(total_hours, day_of_week = 5), 2) as hours_fri,
    round(avgIf(total_hours, day_of_week = 6), 2) as hours_sat,
    round(avgIf(total_hours, day_of_week = 7), 2) as hours_sun,
    round(avgIf(total_hours, day_of_week IN (1,2,3,4,5)), 2) as avg_weekdays_hours,
    round(avgIf(total_hours, day_of_week IN (6,7)), 2) as avg_weekend_hours
FROM days_hours
GROUP BY 1;

--1. Использование аудиокниг (Audiobook):
--Среднее время прослушивания в будние дни (понедельник–пятница) — около 1468 минут.
--В выходные (суббота и воскресенье) время прослушивания падает до примерно 1256 минут.
--Использование аудиокниг снижается в выходные на 14%.
--2. Использование текстовых книг (Book):
--Среднее время чтения в будние дни — около 784 минут.
--В выходные — около 747 минут.
--Чтение книг в выходные снижается на 5%.

--Аудиокниги используются значительно меньше в выходные, чем в будние дни.
--Чтение книг также снижается в выходные, но менее заметно.

--Задание 6

WITH new AS (
    SELECT
        a.usage_platform_ru as platform,
        a.puid,
        a.app_version,
        MAX(a.app_version) OVER (PARTITION BY a.usage_platform_ru) as max_app_version_platform,
        MAX(a.app_version) OVER (PARTITION BY a.usage_platform_ru, a.puid) as max_app_version_user
    FROM source_db.audition a
    WHERE a.usage_platform_ru LIKE '%Букмейт%'
)

SELECT
    platform,
    max_app_version_platform as final_app_version,
    countIf(puid, max_app_version_user = max_app_version_platform) as count_users,
    round(countIf(puid, max_app_version_user = max_app_version_platform)*100 / count(puid),2) AS percent_users
FROM new
GROUP BY 1,2;

--Предположение продакт-менеджера не подтверждается. Наоборот, на Android значительно больше пользователей уже обновились до последней версии, чем на iOS. Это говорит о том, что на Android обновления распространяются быстрее и охватывают большую часть пользователей.
--На iOS процент пользователей с последней версией очень низкий (3.54%), что может говорить о том, что пользователи iOS либо реже обновляют приложение, либо последняя версия только недавно вышла и ещё не успела распространиться. Возможно, на iOS есть проблемы с обновлениями, либо пользователи предпочитают оставаться на старых версиях.
--На Web — 0%, что, возможно, связано с отсутствием обновлений или другой логикой версий.

--Задание 7

WITH version_updates AS (
    SELECT
        a.puid as user_id,
        a.usage_platform_ru as platform,
        CAST(a.msk_business_dt_str AS date) as dt,
        a.app_version,
        leadInFrame(app_version, 1) OVER (PARTITION BY user_id, platform ORDER BY dt ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) AS  next_app_version
    FROM source_db.audition a
    WHERE a.usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
        and a.app_version IS NOT NULL
), 

updates_flagged AS (
    SELECT
        user_id,
        platform,
        countIf(app_version != next_app_version and next_app_version IS NOT NULL) as is_update
    FROM version_updates
    GROUP BY 1,2
)

SELECT
    platform,
    round(sum(is_update) / uniqExact(user_id), 2) as update_rate
FROM updates_flagged
GROUP BY 1
ORDER BY 2 DESC;

--Пользователи Android обновляют приложение в среднем чаще — 3.19 обновлений на пользователя, чем пользователи iOS — 2.43 обновлений.
--Это означает, что средняя частота обновлений у Android выше.
--Предположение продакт-менеджера, что пользователи iOS чаще обновляют приложение, не подтверждается. Наоборот, Android-пользователи обновляются чаще.
--В сочетании с предыдущим анализом (процент пользователей с последней версией) можно сделать вывод, что Android-пользователи не только чаще обновляют приложение, но и в целом быстрее переходят на последние версии.

--Задание 8

SELECT uniqExact(main_content_id) as count_magic_tags_books
FROM source_db.content c
WHERE has(published_topic_title_list, 'Магия');

--Количество книг с тегом «Магия» 46 шт.

--Задание 9

SELECT uniqExact(main_content_name) as books_magic_without_tegs
FROM (SELECT c.main_content_name
		FROM source_db.content c 
		WHERE has(published_topic_title_list,'Магия') = 0 
            and has(published_topic_title_list,'Художественная литература') = 0) as books_without_tegs
WHERE main_content_name ILIKE '%магия%';

--books_magic_without_tegs|
--------------------------+
--47                      |

--Количество книг со словом «магия» в названии, у которых нет тега «Магия» и при этом отсутствует тег «Художественная литература» — 47.

--Задание 10

SELECT 
    round(avg(length(c.published_topic_title_list)), 2) AS avg_category,
    round(avg(if(
                arrayExists(x -> position(x, 'Магия') > 0, c.published_topic_title_list),
                length(c.published_topic_title_list), NULL)), 2) AS avg_category_magic
FROM source_db.content c;

--Среднее количество категорий у всех книг в каталоге — 3.77, что близко к верхней границе рекомендуемого максимума количества категорий (3-4).

--Среднее количество категорий у книг с тегом «Магия» — 3.22, что находится в пределах рекомендуемого диапазона.
--Для этой тематической группы ситуация лучше, чем в целом по каталогу.

--Таким образом, в среднем книги с тегом «Магия» имеют более аккуратное и компактное тегирование, что положительно сказывается на удобстве навигации и поиске.

--Задание 11

SELECT a.usage_country_name as country, 
	   a.usage_platform_ru as platform,
	   round(varPop(hours_sessions_long),2) as variance,
	   round(stddevPop(hours_sessions_long),2) as std,
       round(stddevPop(hours_sessions_long) / avg(hours_sessions_long),2) as rate
FROM source_db.audition a
WHERE a.usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
GROUP BY 1,2
ORDER BY rate DESC
LIMIT 1;

--Аномалия в данных наблюдается в Латвии на платформе Букмейт Android.
--Коэффициент вариации (стандартное отклонение к среднему) здесь очень высокий (7.77), что указывает на сильное разбросанное и нестабильное распределение длины сессий.
--Высокое значение дисперсии (variance = 608.67) и стандартного отклонения (std = 24.67) говорит о том, что данные по длине сессий в этой группе могут быть записаны некорректно или содержать выбросы.


