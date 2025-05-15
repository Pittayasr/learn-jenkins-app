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

# คัดลอกไฟล์ default.conf เพื่อกำหนดค่า Nginx (ถ้ามี)
# COPY default.conf /etc/nginx/conf.d/default.conf

# เปิดพอร์ต 3000
EXPOSE 3000

# คำสั่งเริ่มต้น
CMD ["npm", "start"]
