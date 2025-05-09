# ใช้ Node.js สำหรับการ build แอป
FROM node:18-alpine AS build

# ตั้ง working directory
WORKDIR /app

# คัดลอกไฟล์ package.json และ package-lock.json
COPY package*.json ./

# ติดตั้ง dependencies
RUN npm ci

# คัดลอก source code ทั้งหมด
COPY . .

# สร้าง production build
RUN npm run build

# ใช้ Nginx สำหรับ serve แอป
FROM nginx:alpine

# คัดลอกไฟล์ build ไปยัง directory ของ Nginx
COPY --from=build /app/build /usr/share/nginx/html

# คัดลอกไฟล์ default.conf เพื่อกำหนดค่า Nginx (ถ้ามี)
# COPY default.conf /etc/nginx/conf.d/default.conf

# เปิดพอร์ต 80
EXPOSE 80

# คำสั่งเริ่มต้น
CMD ["nginx", "-g", "daemon off;"]
