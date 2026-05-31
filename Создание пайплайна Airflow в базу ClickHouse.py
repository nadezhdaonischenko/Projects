# %% [markdown]
# # Построение пайплайна в Airflow

# %% [markdown]
# ## Цели и задачи проекта
# 
# Сервис онлайн-книги предоставляет доступ к контенту разных форматов, включая текст, аудио и не только. Построить пайплайн в Airflow, который будет запускать PySpark-скрипт для обработки данных и создания витрин. Эти витрины помогут команде сервиса быстрее и проще готовить отчёты.
# 
# Создать DAG для запуска Spark-кода.

# %% [markdown]
# ## Описание данных
# 
# Таблица `bookmate.audition` содержит данные об активности пользователей и включает столбцы:
# 
# * `audition_id` — уникальный идентификатор сессии чтения или прослушивания;
# 
# * `puid` — идентификатор пользователя;
# 
# * `usage_platform_ru` — название платформы, с помощью которой пользователь взаимодействует с контентом;
# 
# * `msk_business_dt_str` — дата и время события (строка, часовой пояс — МСК);
# 
# * `app_version` — версия приложения;
# 
# * `adult_content_flg` — значение, которое показывает, был ли контент для взрослых (`True` или `False`);
# 
# * `hours` — длительность сессии чтения или прослушивания в часах;
# 
# * `hours_sessions_long` — длительность длинных сессий в часах;
# 
# * `kids_content_flg` — значение, которое показывает, был ли это детский контент (`True` или `False`);
# 
# * `main_content_id` — идентификатор основного контента;
# 
# * `usage_geo_id` — идентификатор географического местоположения пользователя.
# 
# Таблица `bookmate.content` включает столбцы:
# 
# * `main_content_id` — идентификатор основного контента;
# 
# * `main_author_id` — идентификатор основного автора контента;
# 
# * `main_content_type` — тип контента: аудио, текст или другой;
# 
# * `main_content_name` — название контента;
# 
# * `main_content_duration_hours` — длительность контента в часах;
# 
# * `published_topic_title_list` — список жанров или тем контента.</font>

# %% [markdown]
# ## Содержимое проекта
# 
# Проект предполагает несколько шагов:
# 
# 1. Написание Spark-код — подключение к хранилищу данных и указание, куда сохранять результат.
# 
# 2. Создание DAG — запуск Spark-кода.
# 
# 3. Запуск Airflow — управление созданным пайплайном.

# %% [markdown]
# ### Написание Spark-кода

# %% [markdown]
# Данные для подключения к DBeaver:
# 
# *   Имя пользователя — "da_***"
# *   Пароль — "3***"

# %%
from clickhouse_connect import get_client
from pyspark.sql import SparkSession
import pyspark.sql.functions as F
import sys
from datetime import datetime
from airflow import DAG
from airflow.sensors.s3_key_sensor import S3KeySensor
from airflow.providers.yandex.operators.dataproc import DataprocCreatePysparkJobOperator

# %%
client = get_client(
    host="***.cloud.net", # порт и параметры кластера ClickHouse
    port=****,
    username="da_***", # логин
    password="3***",  # пароль 
    secure=True,
    verify=False,
    database="ground_***"  # база
)

print(client.query("SHOW TABLES").result_rows)
print(client.query("SELECT * FROM bookmate_user_aggregate LIMIT 10").result_rows)

# %% [markdown]
# В коде ниже приведён написанный Spark-скрипт. Ваша задача — правильно указать данные для подключения к вашему хранилищу: порты, параметры кластера ClickHouse и путь, куда будут записываться агрегаты.

# %%
# filename=my_spark_job.py

# Создаём Spark-сессию и при необходимости добавляем конфигурации
spark = SparkSession.builder.appName("myAggregateTest").config("fs.s3a.endpoint", "***cloud.net").getOrCreate()

# Указываем порт и параметры кластера ClickHouse
jdbcPort = ****
jdbcHostname = "***cloud.net"
jdbcDatabase = "ground_***"
jdbcUrl = f"jdbc:clickhouse://{jdbcHostname}:{jdbcPort}/{jdbcDatabase}?ssl=true" # путь для записи агрегата

# Получаем аргумент из Airflow
my_date = sys.argv[1].replace('-', '_')

# Считываем исходные данные за нужную дату
df = spark.read.csv(f"s3a://da-plus-dags/script_*/data_{my_date}/*.csv", inferSchema=True, header=True)

# Строим агрегат по пользователям
result_df = df.groupBy("puid").agg(
    F.countDistinct("audition_id").alias("audition_count"),
    F.avg("hours").alias("avg_hours")
)

result_df.write.format("jdbc") \
    .option("url", jdbcUrl) \
    .option("user", "da_***") \
    .option("password", "3***") \
    .option("dbtable", "bookmate_user_aggregate") \
    .mode('append') \
    .save()

# %% [markdown]
# - В результате будет создан файл с названием, указанным в первой строке. Этот файл можно будет запустить с помощью Airflow, но сначала настроим DAG.

# %% [markdown]
# ### Создание DAG
# 
# Теперь, когда Spark-код готов, создим DAG, который будет его запускать.

# %% [markdown]
# #### Создание «каркаса» нового DAG. 
# 
# - DAG должен запускаться каждый день начиная с 1 января 2025 года. При этом запускать DAG за пропущенные даты не нужно.
# 
# - Используйем менеджер контекста `with ... as dag:` — так все задачи будут корректно привязаны к DAG. После конструкции пока напишим `pass`.

# %%
class PysparkJobOperator(DataprocCreatePysparkJobOperator): # создаем оператор
    template_fields = ("cluster_id", "args",)

DAG_ID = "audition_content_analysis"

with DAG(
    dag_id=DAG_ID,
    schedule_interval="@daily", # ежедневно
    start_date=datetime(2025, 1, 1), # с 1 января 2025 года
    catchup=False
) as dag:
  pass

# %% [markdown]
# #### Добавление проверки входного файла. 
# 
# - DAG не должен стартовать, пока в S3 не появится файл с данными за нужную дату.
# 
# - Для решения используем сенсор `S3KeySensor`. Он должен проверять наличие файла каждые 5 минут и ждать максимум час. В качестве аргумента для параметра `bucket_name` укажем строку `"da-plus-dags"`.
# 
# - Файл называется `*.csv`, добавим дату запуска в формате `YYYY_MM_DD`. Путь к данным  должен быть аргументом для параметра `bucket_key` в `S3KeySensor`.

# %%
class PysparkJobOperator(DataprocCreatePysparkJobOperator):
    template_fields = ("cluster_id", "args",

wait_for_input = S3KeySensor(
    task_id="wait_for_input",
    bucket_name="da-plus-dags",                                   # Имя бакета
    bucket_key="script_*/data_{{ ds.replace('-', '_') }}/*.csv",  # Шаблон даты в имени файла
    aws_conn_id="s3",                                             # Подключение S3
    poke_interval=300,                                            # Проверяем каждые 5 минут
    timeout=3600,                                                 # Ждём максимум час
    mode="poke",                                                  # Проверка происходит периодически
    wildcard_match=False
)

# %% [markdown]
# #### Создание задачи для запуска Spark-скрипта через Airflow.

# %%
user = "da_***"

run_pyspark = PysparkJobOperator(
    task_id="run_pyspark",
    name="run_pyspark_job",
    cluster_id="c***",
    args=["{{ ds }}"],
    main_python_file_uri=f"s3a://da-plus-dags/{user}/jobs/my_spark_job.py"
)

# %% [markdown]
# #### Соберем все фрагменты вместе:
# 
# * Опишим DAG с нужными параметрами.
# 
# * Добавим сенсор для ожидания входного файла.
# 
# * Добавим Spark-задачу для запуска скрипта.
# 
# * Настроим зависимости так, чтобы Spark-задача запускалась только после появления файла.

# %% [markdown]
# Данные для подключения к Airflow:
# *   IP — '**.***.***.***'
# *   Имя пользователя — 'da_***'
# *   Пароль — '3***'

# %%
# filename=bookmate_dag.py

class PysparkJobOperator(DataprocCreatePysparkJobOperator):
    template_fields = ("cluster_id", "args",)

with DAG(
    dag_id=DAG_ID,
    schedule_interval="@daily",
    start_date=datetime(2025, 1, 1),
    catchup=False
) as dag:
    # 1) Ждём появления входного файла в S3
    wait_for_input = S3KeySensor(
        task_id="wait_for_input",
        bucket_name="da-plus-dags",                                                         
        bucket_key="script_bookmate/data_{{ ds.replace('-', '_') }}/audition_content.csv", 
        aws_conn_id="s3",                                                                  
        poke_interval=300,                                                               
        timeout=3600,                                                                    
        mode="poke",                                                                        
        wildcard_match=False
    )

    # 2) Запускаем PySpark-задание на кластере Dataproc (оператор Яндекс Облака)
    
    run_pyspark = PysparkJobOperator(
        task_id="run_pyspark",
        name="run_pyspark_job",
        cluster_id="c9q4134h5vi546h1e148",
        args=["{{ ds }}"],
        main_python_file_uri=f"s3a://da-plus-dags/{user}/jobs/bookmate_dag.py",
    )

    # 3)  Зависимости
    wait_for_input >> run_pyspark

# %% [markdown]
# ### Запуск Airflow
# 
# Теперь можно переходить к запуску:
# - В интерфейсе найдем DAG и запустим его.
# - Проверим, что DAG выполнился, а результат соответствует ожиданиям.


