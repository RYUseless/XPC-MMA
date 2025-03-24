from django.urls import path
from . import views

urlpatterns = [
    path('', views.getRoutes),
    path('notes/', views.getNotes),  # pointer na get notes
    path('notes/<int:pk>/', views.getNoteById),
    path('notes/create/', views.createNote),
    path('notes/update/<int:pk>/', views.updateNote),
    path('notes/delete/<int:pk>/', views.deleteNote),
]