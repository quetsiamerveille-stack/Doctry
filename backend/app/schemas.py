from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class TokenPayload(BaseModel):
    token: str
    user: "UserOut"
    requires_otp: bool = True
    otp_ticket: str = ""
    dev_code: str = ""


class InstallStatus(BaseModel):
    admin_install_required: bool
    email_delivery: str
    sms_delivery: str
    ai_engine: str
    min_reward_amount: int
    commission_rate: float


class AdminInstallIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6)
    first_name: str = Field(min_length=1)
    last_name: str = Field(min_length=1)
    phone: str = ""


class SignupIn(BaseModel):
    profile: str = Field(pattern="^(finder|owner)$")
    first_name: str = Field(min_length=1)
    last_name: str = Field(min_length=1)
    email: EmailStr
    password: str = Field(min_length=6)
    phone: str = ""


class LoginIn(BaseModel):
    profile: str = Field(default="owner", pattern="^(finder|owner)$")
    email: EmailStr
    password: str


class AdminLoginIn(BaseModel):
    email: EmailStr
    password: str


class OtpRequestIn(BaseModel):
    email: EmailStr
    purpose: str = "login"


class OtpVerifyIn(BaseModel):
    ticket: str
    code: str


class ProfileUpdateIn(BaseModel):
    first_name: str | None = None
    last_name: str | None = None
    password: str | None = Field(default=None, min_length=6)
    phone: str | None = None


class AdminProfileUpdateIn(BaseModel):
    first_name: str | None = None
    last_name: str | None = None
    email: EmailStr | None = None


class ProfileSwitchIn(BaseModel):
    profile: str = Field(pattern="^(finder|owner|admin)$")


class UserOut(ORMModel):
    id: str
    email: str
    first_name: str
    last_name: str
    phone: str
    role: str
    active_profile: str
    profile_photo: str
    is_admin: bool
    is_blocked: bool
    wallet_balance: float
    average_rating: float
    rating_count: int
    created_at: datetime

    @property
    def full_name(self) -> str:
        return f"{self.first_name} {self.last_name}".strip()


class UserSummary(BaseModel):
    id: str
    first_name: str
    last_name: str
    email: str
    phone: str
    role: str
    profile_photo: str
    is_blocked: bool
    average_rating: float


class DocumentQrIn(BaseModel):
    doc_type: str = Field(min_length=1)
    first_name: str = Field(min_length=1)
    last_name: str = Field(min_length=1)
    phone: str = ""
    email: EmailStr | None = None


class DocumentOut(ORMModel):
    id: str
    doc_type: str
    holder_first_name: str
    holder_last_name: str
    holder_phone: str
    holder_email: str
    qr_id: str
    qr_url: str
    qr_payload: str
    image_url: str
    blurred_url: str
    status: str
    created_at: datetime


class LossDeclarationIn(BaseModel):
    number: int | None = None
    doc_type: str = Field(min_length=1)
    loss_date: datetime | None = None
    description: str = ""
    location: str = ""
    document_id: str | None = None


class RewardIn(BaseModel):
    loss_id: str
    amount: float = Field(gt=0)
    provider: str = Field(default="ORANGE_MONEY", pattern="^(ORANGE_MONEY|MTN_MONEY)$")
    phone: str = ""


class LossDeclarationOut(ORMModel):
    id: str
    number: int
    doc_type: str
    loss_date: datetime
    description: str
    location: str
    owner_name: str
    status: str
    reward_amount: float
    reward_status: str
    document_id: str | None
    matched_find_id: str | None
    owner_id: str
    created_at: datetime
    returned_at: datetime | None


class FindDeclarationIn(BaseModel):
    number: int | None = None
    doc_type: str = Field(min_length=1)
    found_date: datetime | None = None
    description: str = ""
    location: str = ""
    qr_payload: str = ""
    source: str = "manual"


class FindDeclarationOut(ORMModel):
    id: str
    number: int
    doc_type: str
    found_date: datetime
    description: str
    location: str
    holder_name: str
    source: str
    status: str
    finder_id: str
    document_id: str | None
    matched_owner_id: str | None
    image_url: str
    blurred_url: str
    created_at: datetime
    returned_at: datetime | None


class ScanIn(BaseModel):
    payload: str


class MatchOut(ORMModel):
    id: str
    loss_id: str
    find_id: str
    score: float
    engine: str
    reason: str
    status: str
    created_at: datetime
    counterpart_name: str = ""
    counterpart_id: str = ""
    doc_type: str = ""


class PaymentInitiateIn(BaseModel):
    loss_id: str
    amount: float
    provider: str = Field(pattern="^(ORANGE_MONEY|MTN_MONEY)$")
    phone: str = ""


class PaymentConfirmIn(BaseModel):
    reference: str
    pin: str = Field(min_length=4, max_length=8)


class TopUpIn(BaseModel):
    amount: float = Field(gt=0)
    provider: str = Field(default="ORANGE_MONEY", pattern="^(ORANGE_MONEY|MTN_MONEY)$")
    phone: str = ""
    pin: str = Field(min_length=4, max_length=8)


class PaymentOut(ORMModel):
    id: str
    reference: str
    kind: str
    provider: str
    amount: float
    commission: float
    status: str
    message: str
    loss_id: str | None
    phone: str
    created_at: datetime
    settled_at: datetime | None


class ReleaseRequestIn(BaseModel):
    loss_id: str


class ReleaseConfirmIn(BaseModel):
    loss_id: str
    ticket: str
    code: str


class ReturnConfirmIn(BaseModel):
    loss_id: str
    find_id: str


class ConversationStartIn(BaseModel):
    peer_id: str
    subject: str = ""
    loss_id: str | None = None
    find_id: str | None = None


class MessageIn(BaseModel):
    body: str = Field(min_length=1)


class MessageOut(ORMModel):
    id: str
    conversation_id: str
    sender_id: str
    body: str
    read: bool
    created_at: datetime


class ConversationOut(BaseModel):
    id: str
    peer_id: str
    peer_name: str
    peer_role: str
    peer_photo: str
    subject: str
    last_message: str
    last_message_at: datetime | None
    unread_count: int
    loss_id: str | None
    find_id: str | None


class NotificationOut(ORMModel):
    id: str
    title: str
    body: str
    kind: str
    read: bool
    created_at: datetime


class RatingIn(BaseModel):
    stars: int = Field(ge=1, le=5)
    comment: str = ""


class RatingDueOut(BaseModel):
    due: bool
    interval_days: int
    last_rating_at: datetime | None


class StatCell(BaseModel):
    label: str
    value: Any


class OwnerStatsOut(BaseModel):
    loss_declarations: int
    find_declarations: int
    returned_documents: int
    pending_documents: int
    escrow_total: float
    released_total: float


class FinderStatsOut(BaseModel):
    finds_done: int
    rewarded_losses: int
    ongoing: int
    returned_documents: int
    earnings_total: float


class FinanceRow(BaseModel):
    label: str
    amount: float
    count: int


class FinanceOut(BaseModel):
    date: str | None
    day_revenue: float
    month_revenue: float
    year_revenue: float
    total_revenue: float
    escrow_balance: float
    rows: list[FinanceRow]


class AdminStatsOut(BaseModel):
    losses: list[dict[str, Any]]
    finds: list[dict[str, Any]]
    returns: list[dict[str, Any]]
    pending_matching: list[dict[str, Any]]
    counts: dict[str, int]


class ActionResult(BaseModel):
    success: bool
    message: str
    data: dict[str, Any] = {}


TokenPayload.model_rebuild()
