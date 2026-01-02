"""
SMARTCARE+ Nutrition Service Router

Owner: Kulasekara
Endpoints for food recognition, meal logging, RDA-based meal planning, and hydration.
Uses USDA FoodData Central API and local food database.
"""

from fastapi import APIRouter, UploadFile, File, HTTPException
from typing import Optional, List
from pydantic import BaseModel
from datetime import datetime, date
import random

from .models import (
    USDAClient,
    LocalFoodDatabase,
    FoodItem,
    MealPlanGenerator,
    MealLogger,
    MealType,
    RDAProfile,
    DietaryRestriction,
    get_usda_client,
    get_local_food_db,
    get_meal_plan_generator,
    get_meal_logger
)

router = APIRouter()


# Service instances (singleton pattern)
_usda_client: Optional[USDAClient] = None
_local_food_db: Optional[LocalFoodDatabase] = None
_meal_planner: Optional[MealPlanGenerator] = None
_meal_logger: Optional[MealLogger] = None


def get_services():
    """Get or initialize service instances."""
    global _usda_client, _local_food_db, _meal_planner, _meal_logger
    if _usda_client is None:
        _usda_client = get_usda_client()
    if _local_food_db is None:
        _local_food_db = get_local_food_db()
    if _meal_planner is None:
        _meal_planner = get_meal_plan_generator()
    if _meal_logger is None:
        _meal_logger = get_meal_logger()
    return _usda_client, _local_food_db, _meal_planner, _meal_logger


# ============= Pydantic Models =============

class MealLogRequest(BaseModel):
    user_id: str
    foods: List[dict]  # List of {fdc_id or name, portion_multiplier}
    meal_type: str  # breakfast, lunch, dinner, snack
    notes: Optional[str] = None


class GeneratePlanRequest(BaseModel):
    user_id: str
    duration_days: int = 7
    restrictions: Optional[List[str]] = None  # List of DietaryRestriction values
    calorie_target: Optional[int] = None


class HydrationLogRequest(BaseModel):
    user_id: str
    amount_ml: int
    beverage_type: str = "water"


class UserProfileRequest(BaseModel):
    user_id: str
    age: int = 70
    weight_kg: float = 70.0
    height_cm: float = 165.0
    activity_level: str = "sedentary"  # sedentary, light, moderate
    restrictions: Optional[List[str]] = None


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
    """
    Recognize food from image using MobileNetV2 CNN.
    
    Returns detected food with nutrition data from USDA database.
    """
    _, local_db, _, _ = get_services()
    
    # Read image file
    content = await image.read()
    
    # TODO: Actual CNN inference would go here
    # For now, simulate detection with random food from local DB
    all_foods = local_db.get_all_foods()
    
    if not all_foods:
        # Fallback to mock data if DB not loaded
        detected_name = random.choice(["Apple", "Banana", "Oatmeal", "Chicken Breast"])
        food = local_db.search(detected_name)
        if food:
            detected_food = food[0]
        else:
            detected_food = FoodItem(
                fdc_id=0,
                name=detected_name,
                calories=100,
                protein=3,
                carbohydrates=20,
                fat=1
            )
    else:
        detected_food = random.choice(all_foods)
    
    confidence = round(random.uniform(0.85, 0.98), 2)
    
    # Get alternatives
    alternatives = []
    if all_foods:
        alt_foods = random.sample(all_foods, min(3, len(all_foods)))
        alternatives = [f.to_dict() for f in alt_foods if f.name != detected_food.name]
    
    return {
        "status": "completed",
        "detected": {
            "fdc_id": detected_food.fdc_id,
            "name": detected_food.name,
            "confidence": confidence,
            "calories": detected_food.calories,
            "protein": detected_food.protein,
            "carbohydrates": detected_food.carbohydrates,
            "fat": detected_food.fat,
            "fiber": detected_food.fiber,
            "serving_size": f"{detected_food.serving_size} {detected_food.serving_unit}",
        },
        "alternatives": alternatives[:3]
    }


@router.get("/food/{food_id}")
async def get_food(food_id: str):
    """Get detailed nutrition data for a food item from USDA or local DB."""
    usda_client, local_db, _, _ = get_services()
    
    # Try to get from local DB first
    food = local_db.get_by_id(int(food_id)) if food_id.isdigit() else None
    
    if not food:
        # Search local DB by name
        results = local_db.search(food_id)
        food = results[0] if results else None
    
    if not food:
        # Try USDA API
        try:
            food = await usda_client.get_food(int(food_id))
        except:
            raise HTTPException(status_code=404, detail=f"Food '{food_id}' not found")
    
    return {
        "food_id": food_id,
        "nutrition": food.to_dict(),
        "rda_percent": {
            "calories": round((food.calories / 1800) * 100, 1),
            "protein": round((food.protein / 60) * 100, 1),
            "fiber": round((food.fiber / 25) * 100, 1) if food.fiber else 0,
        }
    }


@router.get("/search")
async def search_food(query: str, limit: int = 10, use_usda: bool = False):
    """
    Search food database.
    
    By default searches local database for speed.
    Set use_usda=True to search USDA FoodData Central API.
    """
    usda_client, local_db, _, _ = get_services()
    
    # Search local DB
    local_results = local_db.search(query)
    
    results = [f.to_dict() for f in local_results[:limit]]
    
    # Optionally search USDA API for more results
    if use_usda and len(results) < limit:
        try:
            usda_results = await usda_client.search(query, limit - len(results))
            for food in usda_results:
                results.append(food.to_dict())
        except Exception as e:
            # USDA API error - continue with local results
            pass
    
    return {
        "query": query,
        "results": results[:limit],
        "total": len(results),
        "source": "usda" if use_usda else "local"
    }


@router.post("/log-meal")
async def log_meal(request: MealLogRequest):
    """
    Log a meal entry with detailed nutrition tracking.
    
    Stores meal data and updates daily totals.
    """
    _, local_db, _, meal_logger = get_services()
    
    # Parse meal type
    try:
        meal_type = MealType(request.meal_type.lower())
    except ValueError:
        meal_type = MealType.LUNCH  # Default
    
    # Calculate totals from logged foods
    total_calories = 0
    total_protein = 0
    total_carbs = 0
    total_fat = 0
    logged_foods = []
    
    for food_entry in request.foods:
        food_name = food_entry.get("name", "")
        portion = food_entry.get("portion", 1.0)
        
        # Look up food in database
        results = local_db.search(food_name)
        if results:
            food = results[0]
            total_calories += food.calories * portion
            total_protein += food.protein * portion
            total_carbs += food.carbohydrates * portion
            total_fat += food.fat * portion
            logged_foods.append({
                "name": food.name,
                "portion": portion,
                "calories": round(food.calories * portion, 1)
            })
        else:
            # Use provided values if food not found
            total_calories += food_entry.get("calories", 0) * portion
            logged_foods.append({
                "name": food_name,
                "portion": portion,
                "calories": food_entry.get("calories", 0) * portion
            })
    
    # Log the meal
    log_id = meal_logger.log_meal(
        user_id=request.user_id,
        meal_type=meal_type,
        foods=logged_foods,
        notes=request.notes
    )
    
    return {
        "status": "logged",
        "log_id": log_id,
        "user_id": request.user_id,
        "meal_type": request.meal_type,
        "foods_logged": len(logged_foods),
        "totals": {
            "calories": round(total_calories, 1),
            "protein": round(total_protein, 1),
            "carbohydrates": round(total_carbs, 1),
            "fat": round(total_fat, 1)
        },
        "logged_at": datetime.now().isoformat()
    }


@router.get("/daily-summary/{user_id}")
async def get_daily_summary(user_id: str, date: Optional[str] = None):
    """
    Get daily nutrient intake summary with RDA comparison.
    
    Shows consumed vs. recommended amounts for elderly-specific RDA.
    """
    _, _, meal_planner, meal_logger = get_services()
    
    target_date = date or datetime.now().strftime("%Y-%m-%d")
    
    # Get logged meals for the day
    daily_log = meal_logger.get_daily_log(user_id, target_date)
    
    # Get user's RDA profile (would come from user settings in production)
    rda = RDAProfile()
    
    # Calculate consumed totals
    consumed = daily_log.get("totals", {
        "calories": 0,
        "protein": 0,
        "carbohydrates": 0,
        "fat": 0,
        "fiber": 0
    })
    
    return {
        "user_id": user_id,
        "date": target_date,
        "calories": {
            "consumed": consumed.get("calories", 0),
            "goal": rda.calories,
            "percent": round((consumed.get("calories", 0) / rda.calories) * 100, 1)
        },
        "protein": {
            "consumed": consumed.get("protein", 0),
            "goal": rda.protein,
            "percent": round((consumed.get("protein", 0) / rda.protein) * 100, 1)
        },
        "carbohydrates": {
            "consumed": consumed.get("carbohydrates", 0),
            "goal": rda.carbohydrates,
            "percent": round((consumed.get("carbohydrates", 0) / rda.carbohydrates) * 100, 1)
        },
        "fat": {
            "consumed": consumed.get("fat", 0),
            "goal": rda.fat,
            "percent": round((consumed.get("fat", 0) / rda.fat) * 100, 1)
        },
        "fiber": {
            "consumed": consumed.get("fiber", 0),
            "goal": rda.fiber,
            "percent": round((consumed.get("fiber", 0) / rda.fiber) * 100, 1)
        },
        "meals": daily_log.get("meals", []),
        "recommendations": _get_nutrition_recommendations(consumed, rda)
    }


def _get_nutrition_recommendations(consumed: dict, rda: RDAProfile) -> List[str]:
    """Generate personalized nutrition recommendations."""
    recommendations = []
    
    cal_percent = consumed.get("calories", 0) / rda.calories
    protein_percent = consumed.get("protein", 0) / rda.protein
    fiber_percent = consumed.get("fiber", 0) / rda.fiber
    
    if cal_percent < 0.5:
        recommendations.append("Consider having a nutritious snack to meet your calorie goals")
    
    if protein_percent < 0.6:
        recommendations.append("Include more protein-rich foods like fish, eggs, or legumes")
    
    if fiber_percent < 0.5:
        recommendations.append("Add more fiber through whole grains, fruits, and vegetables")
    
    if not recommendations:
        recommendations.append("Great job! You're on track with your nutrition goals")
    
    return recommendations


@router.get("/meal-plan/{user_id}")
async def get_meal_plan(user_id: str, date: Optional[str] = None):
    """Get current meal plan for the user."""
    _, _, meal_planner, _ = get_services()
    
    target_date = date or datetime.now().strftime("%Y-%m-%d")
    
    # Get or generate meal plan
    plan = meal_planner.get_daily_plan(user_id, target_date)
    
    if plan:
        return {
            "user_id": user_id,
            "date": target_date,
            "meals": plan.to_dict(),
            "total_calories": plan.total_calories,
            "macros": plan.macros
        }
    else:
        # Generate a new plan
        plan = meal_planner.generate_daily_plan(user_id)
        return {
            "user_id": user_id,
            "date": target_date,
            "meals": plan.to_dict() if plan else [],
            "total_calories": plan.total_calories if plan else 0,
            "macros": plan.macros if plan else {}
        }


@router.post("/generate-plan")
async def generate_plan(request: GeneratePlanRequest):
    """
    Generate personalized meal plan based on RDA and dietary restrictions.
    
    Supports restrictions like diabetic, low-sodium, vegetarian, etc.
    """
    _, _, meal_planner, _ = get_services()
    
    # Parse dietary restrictions
    restrictions = []
    if request.restrictions:
        for r in request.restrictions:
            try:
                restrictions.append(DietaryRestriction(r.lower()))
            except ValueError:
                pass  # Skip invalid restrictions
    
    # Create adjusted RDA profile
    rda = RDAProfile()
    if request.calorie_target:
        rda.calories = request.calorie_target
    
    if restrictions:
        rda = rda.adjust_for_restrictions(restrictions)
    
    # Generate meal plan
    plan = meal_planner.generate_weekly_plan(
        user_id=request.user_id,
        days=request.duration_days,
        rda=rda,
        restrictions=restrictions
    )
    
    return {
        "status": "generated",
        "user_id": request.user_id,
        "duration_days": request.duration_days,
        "restrictions_applied": [r.value for r in restrictions],
        "daily_targets": {
            "calories": rda.calories,
            "protein": rda.protein,
            "carbohydrates": rda.carbohydrates,
            "fat": rda.fat
        },
        "plan": plan,
        "generated_at": datetime.now().isoformat()
    }


@router.get("/restrictions")
async def get_available_restrictions():
    """Get list of available dietary restrictions."""
    return {
        "restrictions": [
            {"id": r.value, "name": r.value.replace("_", " ").title(), "description": _get_restriction_description(r)}
            for r in DietaryRestriction
        ]
    }


def _get_restriction_description(restriction: DietaryRestriction) -> str:
    """Get description for dietary restriction."""
    descriptions = {
        DietaryRestriction.DIABETIC: "Low glycemic index foods, controlled carbohydrates",
        DietaryRestriction.LOW_SODIUM: "Reduced sodium intake for heart health",
        DietaryRestriction.LOW_FAT: "Limited fat content for weight management",
        DietaryRestriction.HIGH_FIBER: "Increased fiber for digestive health",
        DietaryRestriction.LOW_CHOLESTEROL: "Reduced cholesterol for heart health",
        DietaryRestriction.LACTOSE_FREE: "No dairy products",
        DietaryRestriction.GLUTEN_FREE: "No wheat, barley, or rye products",
        DietaryRestriction.VEGETARIAN: "No meat or fish",
        DietaryRestriction.SOFT_FOODS: "Easy to chew foods for dental issues",
        DietaryRestriction.KIDNEY_FRIENDLY: "Controlled protein, phosphorus, and potassium",
        DietaryRestriction.HEART_HEALTHY: "Low sodium, low saturated fat, high fiber"
    }
    return descriptions.get(restriction, "")


@router.post("/hydration/log")
async def log_hydration(request: HydrationLogRequest):
    """Log water/fluid intake."""
    _, _, _, meal_logger = get_services()
    
    # Log hydration
    meal_logger.log_hydration(
        user_id=request.user_id,
        amount_ml=request.amount_ml,
        beverage_type=request.beverage_type
    )
    
    return {
        "status": "logged",
        "user_id": request.user_id,
        "amount_ml": request.amount_ml,
        "beverage_type": request.beverage_type,
        "logged_at": datetime.now().isoformat()
    }


@router.get("/hydration/{user_id}")
async def get_hydration(user_id: str, date: Optional[str] = None):
    """Get daily hydration data with recommendations for elderly."""
    _, _, _, meal_logger = get_services()
    
    target_date = date or datetime.now().strftime("%Y-%m-%d")
    
    # Get hydration log
    hydration = meal_logger.get_hydration_log(user_id, target_date)
    
    total_ml = hydration.get("total_ml", 0)
    goal_ml = 2000  # Elderly recommended daily intake
    
    # Calculate glasses (250ml per glass)
    glasses = total_ml // 250
    goal_glasses = goal_ml // 250
    
    # Hydration status and recommendations
    if total_ml >= goal_ml:
        status = "excellent"
        recommendation = "Great job staying hydrated!"
    elif total_ml >= goal_ml * 0.75:
        status = "good"
        recommendation = "You're doing well, try to drink a bit more"
    elif total_ml >= goal_ml * 0.5:
        status = "fair"
        recommendation = "Consider drinking more water throughout the day"
    else:
        status = "low"
        recommendation = "Please drink more fluids. Dehydration is a health risk."
    
    return {
        "user_id": user_id,
        "date": target_date,
        "glasses": glasses,
        "goal_glasses": goal_glasses,
        "total_ml": total_ml,
        "goal_ml": goal_ml,
        "percent": round((total_ml / goal_ml) * 100, 1),
        "status": status,
        "recommendation": recommendation,
        "log": hydration.get("log", [])
    }


@router.get("/rda-profile/{user_id}")
async def get_rda_profile(user_id: str):
    """Get the RDA (Recommended Daily Allowance) profile for a user."""
    # In production, this would come from user settings/database
    rda = RDAProfile()
    
    return {
        "user_id": user_id,
        "profile": {
            "calories": rda.calories,
            "protein": rda.protein,
            "carbohydrates": rda.carbohydrates,
            "fat": rda.fat,
            "fiber": rda.fiber,
            "sodium": rda.sodium,
            "sugar": rda.sugar,
            "vitamins": {
                "vitamin_d": rda.vitamin_d,
                "vitamin_b12": rda.vitamin_b12,
                "vitamin_c": rda.vitamin_c,
                "vitamin_a": rda.vitamin_a
            },
            "minerals": {
                "calcium": rda.calcium,
                "iron": rda.iron,
                "potassium": rda.potassium,
                "magnesium": rda.magnesium
            }
        },
        "age_group": "65+",
        "note": "Values based on dietary guidelines for adults 65 and older"
    }
