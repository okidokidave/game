# 출시용 빌드는 코드를 줄이면서(R8) 쓰지 않는 것처럼 보이는 클래스를 지운다.
# 아래는 실행 중에 이름으로 찾아 쓰는 클래스라서 지우면 앱이 시작하자마자 꺼진다.

# AdMob이 내부에서 쓰는 WorkManager의 Room 데이터베이스 (WorkDatabase_Impl).
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
