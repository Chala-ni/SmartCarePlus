"""
SMARTCARE+ Nutrition Service Router

Owner: Kulasekara
Endpoints for food recognition, meal logging, meal planning, and hydration.
"""

from fastapi import APIRouter, UploadFile, File
from typing import Optional, List
from pydantic import BaseModel
from datetime import datetime
import random

router = APIRouter()


# ============= Pydantic Models =============

class MealLogRequest(BaseModel):
    user_id: str
    foods: List[dict]
    meal_type: str  # breakfast, lunch, dinner, snack
    portion_sizes: Optional[List[float]] = None


class GeneratePlanRequest(BaseModel):
    user_id: str
    duration_days: int = 7
    preferences: Optional[dict] = None


class HydrationLogRequest(BaseModel):
    user_id: str
    amount_ml: int
    beverage_type: str = "water"


# ============= Mock Data =============

FOODS_DB = [
    {"id": "1", "name": "Apple", "calories": 95, "protein": 0.5, "carbs": 25, "fat": 0.3, "fiber": 4, "serving": "1 medium"},
    {"id": "2", "name": "Banana", "calories": 105, "protein": 1.3, "carbs": 27, "fat": 0.4, "fiber": 3, "serving": "1 medium"},
    {"id": "3", "name": "Oatmeal", "calories": 150, "protein": 5, "carbs": 27, "fat": 3, "fiber": 4, "serving": "1 cup cooked"},
    {"id": "4", "name": "Grilled Chicken Breast", "calories": 165, "protein": 31, "carbs": 0, "fat": 3.6, "fiber": 0, "serving": "100g"},
    {"id": "5", "name": "Brown Rice", "calories": 215, "protein": 5, "carbs": 45, "fat": 1.8, "fiber": 3.5, "serving": "1 cup cooked"},
    {"id": "6", "name": "Greek Yogurt", "calories": 100, "protein": 17, "carbs": 6, "fat": 0.7, "fiber": 0, "serving": "170g"},
    {"id": "7", "name": "Salmon", "calories": 208, "protein": 20, "carbs": 0, "fat": 13, "fiber": 0, "serving": "100g"},
    {"id": "8", "name": "Spinach Salad", "calories": 23, "protein": 3, "carbs": 4, "fat": 0.4, "fiber": 2, "serving": "1 cup"},
    {"id": "9", "name": "Almonds", "calories": 164, "protein": 6, "carbs": 6, "fat": 14, "fiber": 3.5, "serving": "1 oz (28g)"},
    {"id": "10", "name": "Avocado", "calories": 240, "protein": 3, "carbs": 12, "fat": 22, "fiber": 10, "serving": "1 whole"},
]

MEAL_PLANS = {
    0: [
        {"type": "Breakfast", "name": "Oatmeal with Berries", "calories": 320, "time": "8:00 AM"},
        {"type": "Lunch", "name": "Grilled Chicken Salad", "calories": 450, "time": "12:30 PM"},
        {"type": "Snack", "name": "Greek Yogurt", "calories": 150, "time": "3:30 PM"},
        {"type": "Dinner", "name": "Baked Salmon with Vegetables", "calories": 520, "time": "7:00 PM"},
    ],
    1: [
        {"type": "Breakfast", "name": "Scrambled Eggs & Toast", "calories": 380, "time": "8:00 AM"},
        {"type": "Lunch", "name": "Vegetable Soup & Bread", "calories": 420, "time": "12:30 PM"},
        {"type": "Snack", "name": "Apple & Almonds", "calories": 180, "time": "3:30 PM"},
        {"type": "Dinner", "name": "Grilled Fish with Rice", "calories": 480, "time": "7:00 PM"},
    ],
}


# ============= REST Endpoints =============

@router.post("/analyze-food")
async def analyze_food(image: UploadFile = File(...)):
    """Recognize food from image using MobileNetV2 CNN."""
    # Simulated food recognition
    detected_food = random.choice(FOODS_DB)
    confidence = round(random.uniform(0.85, 0.98), 2)
    
    return {
        "status": "completed",
        "detected": {
            "name": detected_food["name"],
            "confidence": confidence,
            "calories": detected_food["calories"],
            "protein": detected_food["protein"],
            "carbs": detected_food["carbs"],
            "fat": detected_food["fat"],
            "fiber": detected_food.get("fiber", 0),
            "serving_size": detected_food["serving"],
        },
        "alternatives": random.sample(FOODS_DB, min(3, len(FOODS_DB)))
    }


@router.get("/food/{food_id}")
async def get_food(food_id: str):
    """Get detailed nutrition data for a food item."""
    food = next((f for f in FOODS_DB if f["id"] == food_id), None)
    if not food:
        return {"error": "Food not found", "food_id": food_id}
    
    return {
        "food_id": food_id,
        "nutrition": food,
        "vitamins": {
            "vitamin_a": random.randint(0, 100),
            "vitamin_c": random.randint(0, 100),
            "vitamin_d": random.randint(0, 100),
        },
        "minerals": {
            "calcium": random.randint(0, 200),
            "iron": random.randint(0, 20),
            "potassium": random.randint(0, 500),
        }
    }


@router.get("/search")
async def search_food(query: str, limit: int = 10):
    """Search food database."""
    query_lower = query.lower()
    results = [f for f in FOODS_DB if query_lower in f["name"].lower()]
    
    return {
        "query": query,
        "results": results[:limit],
        "total": len(results)
    }


@router.post("/log-meal")
async def log_meal(request: MealLogRequest):
    """Log a meal entry."""
    total_calories = sum(f.get("calories", 0) for f in request.foods)
    
    return {
        "status": "logged",
        "user_id": request.user_id,
        "meal_type": request.meal_type,
        "total_calories": total_calories,
        "logged_at": datetime.now().isoformat()
    }


@router.get("/daily-summary/{user_id}")
async def get_daily_summary(user_id: str, date: Optional[str] = None):
    """Get daily nutrient intake summary."""
    return {
        "user_id": user_id,
        "date": date or datetime.now().strftime("%Y-%m-%d"),
        "calories": {"consumed": 1450, "goal": 1800},
        "protein": {"consumed": 65, "goal": 80},
        "carbohydrates": {"consumed": 180, "goal": 220},
        "fat": {"consumed": 45, "goal": 60},
        "fiber": {"consumed": 18, "goal": 25},
        "meals": [
            {"type": "Breakfast", "time": "8:00 AM", "calories": 420},
            {"type": "Lunch", "time": "12:30 PM", "calories": 650},
            {"type": "Snack", "time": "3:00 PM", "calories": 180},
        ]
    }


@router.get("/meal-plan/{user_id}")
async def get_meal_plan(user_id: str, date: Optional[str] = None):
    """Get current meal plan."""
    day_index = datetime.now().weekday() % 2  # Alternate between 2 plans
    
    return {
        "user_id": user_id,
        "date": date or datetime.now().strftime("%Y-%m-%d"),
        "meals": MEAL_PLANS.get(day_index, MEAL_PLANS[0]),
        "total_calories": sum(m["calories"] for m in MEAL_PLANS.get(day_index, MEAL_PLANS[0])),
        "macros": {"protein": 85, "carbs": 180, "fat": 55}
    }


@router.post("/generate-plan")
async def generate_plan(request: GeneratePlanRequest):
    """Generate personalized meal plan based on RDA and restrictions."""
    plan = {}
    for day in range(request.duration_days):
        day_key = f"day_{day + 1}"
        plan[day_key] = MEAL_PLANS.get(day % 2, MEAL_PLANS[0])
    
    return {
        "status": "generated",
        "user_id": request.user_id,
        "duration_days": request.duration_days,
        "plan": plan,
        "generated_at": datetime.now().isoformat()
    }


@router.post("/hydration/log")
async def log_hydration(request: HydrationLogRequest):
    """Log water/fluid intake."""
    return {
        "status": "logged",
        "user_id": request.user_id,
        "amount_ml": request.amount_ml,
        "beverage_type": request.beverage_type,
        "logged_at": datetime.now().isoformat()
    }


@router.get("/hydration/{user_id}")
async def get_hydration(user_id: str, date: Optional[str] = None):
    """Get daily hydration data."""
    glasses = random.randint(4, 7)
    
    return {
        "user_id": user_id,
        "date": date or datetime.now().strftime("%Y-%m-%d"),
        "glasses": glasses,
        "goal_glasses": 8,
        "total_ml": glasses * 250,
        "goal_ml": 2000,
        "log": [
            {"time": "7:30 AM", "amount": 250, "type": "Water"},
            {"time": "9:00 AM", "amount": 250, "type": "Water"},
            {"time": "10:30 AM", "amount": 200, "type": "Tea"},
            {"time": "12:00 PM", "amount": 250, "type": "Water"},
            {"time": "2:30 PM", "amount": 250, "type": "Water"},
            {"time": "4:00 PM", "amount": 250, "type": "Water"},
        ][:glasses]
    }
