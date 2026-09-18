-- ============================================
-- جدول الملفات الشخصية (يربط اسم المستخدم بدوره)
-- ============================================
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  username text not null,
  role text not null default 'user',
  banned boolean not null default false,
  created_at timestamptz default now()
);

alter table profiles enable row level security;

-- دالة تتحقق إذا كان المستخدم الحالي أدمن (بدون تكرار لا نهائي)
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select coalesce((select role = 'admin' from profiles where id = auth.uid()), false);
$$;

-- كل مستخدم يشوف ملفه فقط، والأدمن يشوف الكل
create policy "select_own_profile" on profiles for select using (auth.uid() = id);
create policy "admin_select_all_profiles" on profiles for select using (is_admin());
create policy "admin_update_profiles" on profiles for update using (is_admin());

-- إنشاء ملف شخصي تلقائيًا لكل حساب جديد
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (new.id, split_part(new.email, '@', 1));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- إنشاء ملفات شخصية للحسابات الموجودة مسبقًا (التجريبية)
insert into public.profiles (id, username)
select id, split_part(email, '@', 1) from auth.users
where id not in (select id from public.profiles);

-- ============================================
-- جدول الإعلانات (تظهر لكل المستخدمين)
-- ============================================
create table announcements (
  id bigint generated always as identity primary key,
  message text not null,
  created_at timestamptz default now()
);

alter table announcements enable row level security;
create policy "everyone_reads_announcements" on announcements for select using (true);
create policy "admin_writes_announcements" on announcements for insert with check (is_admin());
create policy "admin_deletes_announcements" on announcements for delete using (is_admin());

-- ============================================
-- صلاحيات الأدمن على بيانات كل التجار (قراءة وحذف فقط)
-- ============================================
create policy "admin_select_all_products" on products for select using (is_admin());
create policy "admin_delete_all_products" on products for delete using (is_admin());

create policy "admin_select_all_debts" on debts for select using (is_admin());
create policy "admin_delete_all_debts" on debts for delete using (is_admin());

create policy "admin_select_all_payments" on payments for select using (is_admin());
create policy "admin_delete_all_payments" on payments for delete using (is_admin());

create policy "admin_select_all_expenses" on expenses for select using (is_admin());
create policy "admin_delete_all_expenses" on expenses for delete using (is_admin());
